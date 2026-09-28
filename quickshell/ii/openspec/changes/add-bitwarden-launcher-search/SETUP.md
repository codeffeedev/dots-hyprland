# Bitwarden launcher search — setup

## 1. Log in once

`bw` keeps its own encrypted vault on disk. Log in from a terminal; the shell never
handles your login credentials.

```bash
bw login            # email + master password (+ 2FA)
```

Check it worked:

```bash
bw status | jq -r .status    # -> "locked"
```

`unauthenticated` means the login did not complete. The launcher reports each of these
states directly rather than showing an empty result list.

## 2. Enable the feature

Settings → Services → Search → Bitwarden vault, or directly:

```jsonc
// ~/.config/illogical-impulse/config.json
"search": {
  "bitwarden": {
    "enable": true,
    "sensitiveClearSeconds": 30,
    "syncIntervalMinutes": 0,
    "useKeyringMasterPassword": false,
    "notifyOnCopy": true,
    "sensitiveClearMode": "timeout"
  },
  "prefix": { "bitwarden": "!" }
}
```

## 3. Use it

Open the launcher and type `!` followed by a site, username or URL:

```
!github
```

- **Enter** — copy the password
- **Secondary actions** — copy username, copy TOTP code, open the site
- `/bwlock` — lock the vault
- `/bwsync` — pull remote changes

While the vault is locked, `!` shows a single "Unlock the Bitwarden vault" result.

## 4. Choosing an unlock mode

### Interactive (default, recommended)

A prompt appears; the session stays unlocked until you lock it or restart the shell.
The session key lives only in shell memory and is never written to disk.

### Keyring-backed, non-interactive (opt-in)

```bash
secret-tool store --label='Bitwarden master password' \
    application illogical-impulse service bitwarden-master
```

Then enable "Unlock using a master password from the keyring".

**Understand the trade-off before enabling this.** If your login keyring unlocks
automatically when you log into your desktop — the usual configuration — then storing the
master password there means the Bitwarden vault unlocks with your graphical session
alone. Bitwarden's lock stops being a second factor and becomes decorative. Anyone who
reaches an unlocked session reads the whole vault without knowing the master password.

It is off by default for that reason. On this machine the login keyring is *not*
auto-unlocked (`scripts/keyring/is_unlocked.sh` reports locked), so the helper returns
exit code 2 until the keyring is unlocked.

## 5. Clipboard behaviour

Copied secrets are marked sensitive with `wl-copy --sensitive`, so `wl-paste --watch`
reports `CLIPBOARD_STATE=sensitive` and `cliphist` declines to store them. They do not
appear in `cliphist list` nor under the `;` clipboard prefix. Verified empirically.

`sensitiveClearMode`:

| Mode | Behaviour |
|------|-----------|
| `timeout` (default) | Clears after `sensitiveClearSeconds`, unless you copied something else in the meantime. |
| `pasteOnce` | Adds `wl-copy --paste-once`. **Unreliable here** — see below. |
| `never` | Stays until replaced. Still excluded from history. |

### Why `pasteOnce` is not the default

`wl-paste --watch` has to *read* the clipboard in order to pipe it to its child process.
The `CLIPBOARD_STATE=sensitive` hint only reaches `cliphist` after `wl-paste` has already
consumed the offer — the man page confirms stdin is detached only for the `nil` and
`clear` states, not `sensitive`. With a clipboard watcher running (this machine has two
for `cliphist`, plus a third), the single paste permitted by `--paste-once` is spent by
the watcher within milliseconds and you would paste nothing. Use it only if you run no
clipboard watcher at all.

## 6. What the shell can and cannot see

- The **session key** is held in one in-memory property and passed to `bw` only through
  `BW_SESSION`. `/proc/<pid>/environ` is mode 0400 — owner-only — whereas
  `/proc/<pid>/cmdline` is world-readable, which is why nothing sensitive is ever an
  argument.
- The **item index** holds only id, name, username, URIs, and booleans for whether a
  password and a TOTP seed exist. `bw list items` emits the fully decrypted vault, so a
  `jq` allow-list strips it inside the pipeline before anything reaches QML.
- **Secrets** are fetched per action and streamed to the clipboard by a child process.
  They are never assigned to a QML property.

## 7. Performance

`bw` is a Node application and takes roughly 1–2 seconds per cold invocation. Searching
is instant because it runs against the cached index; only the copy itself pays that cost.
No `bw` process is spawned per keystroke.
