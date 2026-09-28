## Context

The shell's launcher (`services/LauncherSearch.qml`) already multiplexes providers behind single-character prefixes configured in `modules/common/Config.qml:486`. Adding the vault means adding one more provider — structurally trivial. The difficulty is entirely in handling secrets safely inside a shell that was not built with secrets in mind.

Three properties of the current environment drive the design:

1. **`Cliphist.copy` is not a safe template.** `services/Cliphist.qml:56` interpolates the payload into a `bash -c` string. Argument vectors are world-readable via `/proc/<pid>/cmdline` on a default Linux configuration, so any local process — any user — can read a secret passed that way. Environment blocks (`/proc/<pid>/environ`) are mode `0400`, owner-only, and are therefore strictly safer.
2. **Every clipboard write is harvested.** Two `wl-paste --watch ... cliphist store` processes are running (observed pids 2161 text, 2163 image). Anything copied normally lands in `~/.cache/cliphist/db` in plaintext, permanently, and becomes fuzzy-searchable from the `;` prefix.
3. **`bw` is slow.** It is a Node application; cold invocations run 1-2 seconds. It cannot sit in the keystroke path.

Verified on this machine: `bw` 2026.2.0, `jq` 1.8.2, `wl-copy` with `--sensitive`, `secret-tool` present, `cliphist` 0.7.0 (the `CLIPBOARD_STATE` symbol is in the binary), Quickshell 0.2.1. `Process.environment` is already used in-repo for secret injection at `services/Ai.qml:669` and `services/Network.qml:105`.

## Goals / Non-Goals

**Goals:**

- Retrieve a credential from the launcher without the secret entering the shell's memory, any process's argument vector, the clipboard history database, or the filesystem.
- Keep per-keystroke latency equal to the existing clipboard provider by serving matches from a cached, secret-free index.
- Degrade with an explanation — locked, logged out, CLI missing each produce an actionable result rather than silence.

**Non-Goals:**

- KeePassXC, `rbw`, or any second backend. The service boundary permits one later; this change does not build it.
- Vault mutation of any kind — no create, edit, or delete.
- Replacing Bitwarden's own storage. The `bw` CLI's local encrypted vault remains the only at-rest copy.
- Hardening the existing `Cliphist` path. It remains as-is for ordinary text.

## Decisions

### Use the `bw` CLI directly, not `bw serve` and not `rbw`

`rbw` would be materially better — an agent daemon holding the session, sub-100ms lookups, pinentry unlock — but the requirement is to use `bitwarden-cli`, and `rbw`'s unofficial protocol implementation is a real maintenance consideration.

`bw serve` was considered as a latency fix: it exposes a REST API on `localhost:8087`, eliminating cold start entirely. **Rejected on security grounds.** That API has no authentication whatsoever; while it runs, any local process — including any web page's helper, any npm postinstall script — can read the entire decrypted vault over HTTP. Trading process-level isolation for latency is the wrong trade for a credential store.

The cost of this decision is the 1-2s cold start, which is paid only on index refresh and on individual copy actions, never per keystroke.

### Session key travels in the environment, never in argv

Every `bw` invocation runs through a `Process` with `environment: { BW_SESSION: <key> }`. The key is held in one QML property, never serialised, never logged. On shell reload it is lost and state is re-derived from `bw status`.

The vault item id is also passed by environment rather than as an argument. The id is not itself a secret, but keeping the whole pipeline out of argv means there is no per-call judgement about what is safe to expose.

### The index is stripped by `jq` before it reaches QML

`bw list items` emits the full decrypted vault, passwords included. That JSON must never be parsed by the shell. A `jq` filter in the same pipeline reduces it to non-secret fields, so the secrets exist only in the `bw` and `jq` process memory and die with the pipeline:

```
bw list items --nointeraction \
  | jq -c '[.[] | select(.type == 1) | {
      id,
      name,
      username: (.login.username // ""),
      uris: [.login.uris[]?.uri // empty],
      totp: ((.login.totp // "") != "")
    }]'
```

`type == 1` selects login items; cards, identities and secure notes are out of scope and excluded at the source. Only this array's text is read by `StdioCollector`.

**Revised during implementation:** the filter carries a sixth key, `hasPassword: ((.login.password // "") != "")`. The launcher must be able to honour "item has no password → clipboard unchanged" *before* spawning `bw`; without a presence flag the only signal would be a failed fetch. Like `totp`, it is a boolean — presence, never the value. Verified against a payload containing a password, TOTP seed, secure note, custom field and card number: no secret substring survives the filter.

### Copy is a pipeline the shell never reads

```qml
Process {
    command: ["bash", "-c", "bw get password \"$BW_ITEM_ID\" --nointeraction | wl-copy --sensitive --trim-newline"]
    environment: ({ BW_SESSION: vault.session, BW_ITEM_ID: itemId })
    // deliberately no stdout parser attached
}
```

The secret passes from `bw`'s stdout to `wl-copy`'s stdin inside the child shell. It is never in argv, never in QML memory, never in a file. Attaching a `stdout` collector here would defeat the entire design, which is why it is called out explicitly rather than left implicit.

Failure detection uses `set -o pipefail` and the process exit code, not output inspection.

**Revised during implementation — the direct pipe is unsafe.** Piping runs `bw` and `wl-copy` concurrently, so when `bw` fails it still closes the pipe and `wl-copy` publishes an *empty* clipboard value, violating the requirement that a failed copy leave the clipboard untouched. The shipped wrapper therefore buffers into a bash variable and emits it with the `printf` **builtin**, which forks no process and so creates no `/proc` entry:

```bash
set -o pipefail
value=$("$@") || exit 10          # producer failed
[ -n "$value" ] || exit 11        # nothing to copy
printf '%s' "$value" | wl-copy --foreground --sensitive --trim-newline >/dev/null 2>&1 &
```

The producer command arrives as `"$@"` rather than through the environment, which also removes the need for `eval`. The vault item id is an ordinary argument; it is an identifier, not a secret. Verified: exit 10 and exit 11 both leave the prior clipboard value intact.

`wl-copy` must have its stdio redirected. Backgrounded without it, it inherits the pipe and keeps it open after the wrapper exits, so `Process` may never observe EOF.

### Retention is a timed clear, not `--paste-once`

`wl-copy --paste-once` is the obvious choice and it is **wrong here**. In `--watch` mode `wl-paste` reads the clipboard data in order to pipe it to its child; the man page confirms stdin is only detached for the `nil` and `clear` states, not for `sensitive`. The `CLIPBOARD_STATE=sensitive` hint reaches `cliphist` *after* `wl-paste` has already consumed the offer. With the two watchers running, the single paste permitted by `--paste-once` would be spent by the watcher within milliseconds and the user would paste nothing.

So the default is a timeout-based clear, guarded so it never destroys a value the user copied afterwards.

**Revised during implementation — the guard needs no copy of the secret at all.** `wl-copy --foreground` *is* the selection owner, and it exits by itself the moment any other client takes the selection. So the guard simply kills that pid after the timeout:

```bash
setsid --fork bash -c '
    sleep "$1"
    [ "$(cat /proc/"$2"/comm 2>/dev/null)" = "wl-copy" ] && kill "$2" 2>/dev/null
' _ "$CLEAR_SECONDS" "$wl_pid" >/dev/null 2>&1 &
```

If the user copied something else in the interim, our `wl-copy` is already gone and the kill is a no-op; the `comm` check covers pid reuse. This deletes the earlier plan's comparison step and with it the one place the no-secrets-in-shell-memory rule was going to bend. Verified both ways: the clipboard clears on timeout, and a value the user copied afterwards survives.

A `sensitiveClearMode` config key offers `timeout` (default), `pasteOnce` (documented as unreliable while a clipboard watcher runs), and `never`.

`--sensitive` is applied in all three modes; history exclusion is not optional.

### Two services, not one

`SecretClipboard` knows nothing about Bitwarden — it accepts a command to run and pipes its output to the clipboard safely. `BitwardenVault` knows nothing about the clipboard. This keeps the security-critical surface small and auditable in one file, and means a future KeePassXC backend reuses the hardened path rather than reimplementing it.

### Non-interactive unlock is opt-in and off by default

`bw unlock --raw --passwordenv VAR` (verified present) allows unlocking from a master password held by `secret-tool`, using its own attribute set (`application=illogical-impulse`, `service=bitwarden-master`) rather than the JSON blob that `services/KeyringStorage.qml` maintains — that blob is read wholesale into memory, which is inappropriate for a master password.

**This is a genuine security downgrade and is therefore default-off.** If gnome-keyring auto-unlocks on login — the common configuration — storing the master password there means the Bitwarden vault is effectively unlocked by the graphical session alone. Bitwarden's lock becomes decorative. Users who want one-keystroke access can opt in knowingly; the default path is an explicit unlock.

The default unlock is a prompt in the shell, which necessarily holds the typed master password in a QML string for the duration of the `bw unlock` call, then clears it. A GUI prompt cannot avoid this.

### `bw sync` is scheduled or manual, never implicit

Syncing is a network round trip on top of Node startup. It runs on a configurable interval (default: on unlock only) and via a `/bwsync` launcher action. A failed sync leaves the existing index intact — an offline laptop keeps working.

## Risks / Trade-offs

- **Cold-start latency of 1-2s on copy** → The index makes searching instant; only the final copy pays. A notification confirms completion so the delay is legible rather than looking like a dropped keypress.
- **Master password in the keyring collapses two factors into one** → Default off, documented at the config key, and the interactive path is the default.
- ~~**The clear-timeout guard reads the secret into shell memory**~~ → Resolved during implementation: the guard kills the owning `wl-copy` process instead of comparing values, so it never touches the secret.
- **`wl-copy` holds the secret in its own memory while it owns the selection** → Unavoidable; that is how the Wayland clipboard works, since the owner serves the data on request. Bounded by the clear timeout.
- **`jq` filter drift** → If Bitwarden changes its item JSON, a malformed filter could pass secret fields through to QML. The filter is an explicit allow-list of five keys, never a deny-list, so new upstream fields are dropped by construction.
- **Index reflects the vault at refresh time** → Credentials changed on another device are stale until the next sync. Acceptable; surfaced by the manual sync action.
- **Notifications leak item names to the notification daemon** → Names, never secrets. Users for whom item names are sensitive can disable the notification.
- **A third watcher (`wl-paste --watch echo clipboard-changed`, pid 2342) also consumes offers** → Reinforces the rejection of `--paste-once`; it does not persist anything.

## Migration Plan

Additive throughout: two new service files, one new branch in `LauncherSearch.qml`, new config keys. No existing behaviour changes, so rollback is deleting the services and reverting the two edited files. Disabling `search.bitwarden.enable` neutralises the feature without removing code, and when `bw` is absent the service is inert by design.

## Open Questions

- Should the vault prefix default to `!`? It is unused by the existing providers (`/`, `>`, `;`, `:`, `=`, `$`, `?`) but is shell history expansion, which may feel wrong to type.
- Should a successful copy auto-type instead, via the existing `services/Ydotool.qml`? Deferred — it widens the attack surface and the clipboard path must work first.
- Should organisation-owned items be distinguishable in results, or is the item name always sufficient?
