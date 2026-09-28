## 1. Configuration surface

- [x] 1.1 Add `bitwarden` JsonObject to the `search` section of `modules/common/Config.qml:481` with `enable` (default `false`), `syncIntervalMinutes` (default `0`, meaning sync on unlock only), `useKeyringMasterPassword` (default `false`), `sensitiveClearMode` (default `"timeout"`), `sensitiveClearSeconds` (default `30`), and `notifyOnCopy` (default `true`)
- [x] 1.2 Add `property string bitwarden: "!"` to the prefix JsonObject at `modules/common/Config.qml:486`
- [x] 1.3 Verify defaults materialise into `~/.config/illogical-impulse/config.json` on next shell start without clobbering existing user keys. **Finding:** the file is a full dump, but `FileView` only rewrites it on `onAdapterUpdated`, so newly added defaults do not appear on disk until some setting is changed — they are live in memory immediately. Confirmed live: `panelFamilies/IllogicalImpulseFamily.qml` now evaluates `Config.options.search.bitwarden.enable` on every load and produces no "property of undefined" warning, which is exactly the error an absent section raises

## 2. Secret clipboard service

- [x] 2.1 Create `services/SecretClipboard.qml` as a singleton exposing `copyFromCommand(argv, environment, label)` — it runs the producer with `bash -c`, emits its output into `wl-copy --sensitive --trim-newline`, and attaches no stdout parser
- [x] 2.2 Use `set -o pipefail` in the wrapper and treat a non-zero exit as failure, leaving the clipboard untouched. **Revised during implementation:** the producer's output is buffered in a bash variable and emitted via the `printf` builtin rather than piped directly, because a direct pipe runs producer and `wl-copy` concurrently and a failing producer would still close the pipe and overwrite the clipboard with an empty value. The `printf` builtin forks no process, so nothing reaches an argument vector. Verified: exit 10 on producer failure and exit 11 on empty output both leave the clipboard at its prior value
- [x] 2.3 Implement `sensitiveClearMode: "timeout"`. **Revised during implementation:** no value comparison is needed. `wl-copy --foreground` is itself the selection owner and exits on its own when any other client takes the selection, so killing that pid after the timeout clears the clipboard only if our value is still current. This removes the design's "reads the secret into shell memory" caveat entirely. Verified: clears after the timeout, and does not clear when the user copied something else in the interim
- [x] 2.4 Implement `sensitiveClearMode: "pasteOnce"` by adding `--paste-once`, and `"never"` as no clearing at all
- [x] 2.5 Emit `copySucceeded(label)` / `copyFailed(label, reason)` signals carrying the item label only, never the value
- [x] 2.6 Add a plain `copyText(value, label)` path for non-secret values such as usernames, still marked `--sensitive` so history stays clean. Value travels via the environment, never argv
- [x] 2.7 Verify a secret copy adds no row to `~/.cache/cliphist/db` by comparing `cliphist list | wc -l` before and after — verified, count unchanged at 39 and the canary is absent from `cliphist list`
- [x] 2.8 Verify no secret appears in `/proc/*/cmdline` by sampling during a copy — verified with a canary generated inside the test script so it never enters the harness or scanner command lines; zero non-scanner processes ever exposed it. Also confirmed `/proc/self/environ` is mode 0400, so the environment channel is owner-only

## 3. Bitwarden vault service — state and session

- [x] 3.1 Create `services/BitwardenVault.qml` as a singleton with a `state` property over `unavailable` / `unauthenticated` / `locked` / `unlocked`
- [x] 3.2 Detect the CLI once at startup; if `bw` is not on `PATH`, set `unavailable` and short-circuit every subsequent operation
- [x] 3.3 Parse `bw status --raw` JSON into the state property, and re-derive state on shell reload
- [x] 3.4 Hold the session key in a single in-memory property, passed to children only as `BW_SESSION` via `Process.environment`
- [x] 3.5 Detect session rejection from failed vault commands, transition to `locked`, and discard both session key and index
- [x] 3.6 Add `lock()` running `bw lock`, clearing session key and index

## 4. Bitwarden vault service — unlock

- [x] 4.1 Add the keyring unlock helper. **Revised during implementation:** written as `scripts/keyring/bw_unlock.sh`, which looks the password up *and performs the unlock itself*, printing only the resulting session key. The original "lookup" framing would have piped the master password through the helper's stdout and straight into QML memory, defeating the point. Exit codes: 1 not stored, 2 keyring locked, 3 rejected by `bw`. Verified: returns 2 on this machine, since the login keyring is not auto-unlocked here
- [x] 4.2 Implement non-interactive unlock — `bw unlock --raw --passwordenv BW_PASSWORD` with the password injected through `Process.environment` — gated on `useKeyringMasterPassword`
- [x] 4.3 Implement the interactive unlock prompt, clearing the typed password property immediately after the unlock process starts
- [x] 4.4 On authentication failure, remain `locked`, surface the error, and do not retry automatically
- [x] 4.5 On unlock success, cache the session key, set `unlocked`, and trigger an index build
- [x] 4.6 Add a settings affordance for storing the master password in the keyring that states plainly that it weakens the vault lock

## 5. Bitwarden vault service — index and secrets

- [x] 5.1 Implement `refreshIndex()` running the `bw list items | jq` pipeline from design.md, collecting only the filtered JSON array
- [x] 5.2 Confirm the `jq` filter is an allow-list and that no other field can reach QML. **Revised during implementation:** six keys, not five — `hasPassword` was added as a boolean presence flag. Without it the launcher cannot honour "item has no password → clipboard SHALL NOT be modified" before invoking `bw`, since a failing fetch would otherwise be the only signal. It records presence, never the value. Verified against a representative payload containing a password, TOTP seed, secure note, custom field and card: every secret substring absent from the filtered output, and non-login item types dropped by `select(.type == 1)`
- [x] 5.3 Store the parsed index plus a `Fuzzy.prepare`-built search structure covering name, username and URIs, mirroring `services/Cliphist.qml:19-43`
- [x] 5.4 Clear the index whenever state leaves `unlocked`
- [x] 5.5 Implement `fuzzyQuery(search)` returning index entries, honouring `Config.options.search.sloppy` like the clipboard provider
- [x] 5.6 Implement `copyPassword(item)`, `copyTotp(item)` and `copyUsername(item)` delegating to `SecretClipboard` with `BW_ITEM_ID` passed by environment
- [x] 5.7 Implement `sync()` running `bw sync`, rebuilding the index on success and preserving the old index on failure
- [x] 5.8 Add the interval timer for `syncIntervalMinutes`, disabled when zero
- [x] 5.9 Add an `indexLoading` property so the launcher can distinguish "loading" from "empty vault"

## 6. Launcher integration

- [x] 6.1 Add the bitwarden prefix to the guard list in `services/LauncherSearch.qml:18` so `ensurePrefix` replaces rather than appends
- [x] 6.2 Add a vault branch alongside the clipboard branch at `services/LauncherSearch.qml:174`, returning only vault results and gated on `Config.options.search.bitwarden.enable`
- [x] 6.3 Map index entries to `LauncherSearchResult` objects showing name and username, with `type` set to a translated "Password" label and a Material key icon
- [x] 6.4 Wire the primary `execute` to `copyPassword`, and handle the no-password case by notifying instead of copying
- [x] 6.5 Add secondary actions for copy-username and open-URI, and add copy-TOTP only when the index entry records a seed
- [x] 6.6 Return a single actionable result for each of the `locked`, `unauthenticated` and `unavailable` states, with unlock wired to the unlock flow
- [x] 6.7 Re-evaluate the pending query after an unlock triggered from the launcher completes
- [x] 6.8 Show a loading result while `indexLoading` is true rather than an empty list
- [x] 6.9 Add `bwlock` and `bwsync` entries to `searchActions` in `services/LauncherSearch.qml:64`

## 7. Verification against specs

- [ ] 7.1 Vault state — confirm all four states render their intended launcher result, including with `bw` renamed away to force `unavailable`
- [ ] 7.2 Session hygiene — grep the shell config tree and runtime logs for the session key to confirm it is never persisted
- [ ] 7.3 Index hygiene — dump the in-memory index and confirm no password, TOTP seed, or note field is present
- [ ] 7.4 Clipboard history — confirm a copied password is absent from both `cliphist list` and the `;` launcher prefix
- [ ] 7.5 Argv hygiene — confirm no secret is visible in `/proc/*/cmdline` during copy, using a second user account if available
- [ ] 7.6 Retention — confirm the timed clear fires, and confirm it does not clear when the clipboard changed in the meantime
- [ ] 7.7 Matching — confirm name, username and URI-host queries each surface the expected item, and that an empty query lists all items
- [ ] 7.8 Isolation — confirm no vault item appears in an unprefixed query, and none appear when the feature is disabled
- [ ] 7.9 Offline behaviour — disconnect the network, run sync, and confirm the cached index survives
- [ ] 7.10 Latency — confirm typing in the vault prefix spawns no `bw` process, by watching `pgrep -f "bw "` during a query

## 8. Documentation

- [x] 8.1 Document setup in the change folder — `bw login`, enabling the feature, choosing the unlock mode (see `SETUP.md`)
- [x] 8.2 Document the keyring trade-off and the exact `secret-tool store` invocation for opting in
- [x] 8.3 Note that `pasteOnce` is unreliable while a `wl-paste --watch` clipboard watcher is running, and why
