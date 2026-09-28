## Why

Retrieving a credential today means leaving the keyboard flow: open the Bitwarden desktop app, unlock it, search, click copy. The shell already has a fast fuzzy launcher (`Overview` search) that handles apps, clipboard history, emojis and math through prefixes, so the vault is the obvious missing provider.

Naively wiring `bw` into it is unsafe: the shell's existing clipboard path (`services/Cliphist.qml:56`) interpolates payloads into a `bash -c` string, and every clipboard write is captured by the `cliphist` watcher into a plaintext database at `~/.cache/cliphist/db`. Copying a password through that path would persist it forever and make it fuzzy-searchable from the `;` clipboard prefix. The vault integration therefore has to come with a hardened copy path.

## What Changes

- Add a launcher search prefix that queries the local Bitwarden vault by item name, username and URI, and copies the password of the chosen item.
- Add a `BitwardenVault` singleton service wrapping `bw` (session lifecycle, locked/unlocked state, item index, sync).
- Vault items are indexed **without** their secrets: only `id`, `name`, `login.username`, `login.uris[].uri` and `totp` presence are held in shell memory. Secrets are fetched per-invocation and streamed straight to the clipboard.
- Add a secret-aware clipboard copy path that marks content sensitive so the `cliphist` watcher skips it, and that never places a secret in process arguments.
- Offer secondary result actions: copy username, copy TOTP code, open the item's URI.
- Unlock is non-interactive when a master password is present in the keyring, and falls back to an explicit unlock action otherwise. The session key is never written to disk and never passed as a command-line argument.
- Add config options under `search` (prefix, enable flag, clipboard clear behaviour, sync interval).

Non-goals: KeePassXC support, two-way sync between password managers, editing or creating vault items, and storing the vault offline in any form the `bw` CLI does not already maintain.

## Capabilities

### New Capabilities

- `bitwarden-vault-access`: Session and vault-state management on top of the `bw` CLI — lock/unlock lifecycle, non-interactive unlock from the keyring, the secret-free item index, on-demand secret retrieval, and vault synchronisation.
- `secret-clipboard`: Clipboard writes for sensitive values — exclusion from clipboard history, absence of secrets from process arguments and shell memory, and bounded clipboard lifetime.
- `launcher-vault-search`: The launcher-facing surface — prefix routing, fuzzy matching over the item index, result presentation, and secondary actions.

### Modified Capabilities

None. `openspec/specs/` is empty; the existing launcher and clipboard behaviour has never been captured as a spec, so this change introduces its capabilities rather than amending any.

## Impact

Affected code:

- `services/BitwardenVault.qml` (new) — vault service singleton.
- `services/SecretClipboard.qml` (new) — hardened copy path.
- `services/LauncherSearch.qml` — new prefix branch beside the clipboard branch at `:174`, and the prefix added to the `ensurePrefix` guard list at `:18`.
- `modules/common/Config.qml` — new keys in the `search` section at `:481` and its `prefix` object at `:486`.
- `scripts/keyring/` — lookup helper for the master password, alongside the existing `try_lookup.sh` used by `services/KeyringStorage.qml:96`.

Dependencies: `bitwarden-cli` (`bw` 2026.2.0, installed), `jq` (1.8.2, installed), `wl-clipboard` with `--sensitive` support (installed), `libsecret` / `secret-tool` (installed). No new package is required.

Systems: relies on the running `wl-paste --watch ... cliphist store` watchers (pids observed at 2161/2163) honouring `CLIPBOARD_STATE=sensitive`, which `cliphist` 0.7.0 does.

Risk: `bw` is a Node process with roughly 1-2s cold start, so the vault index must be cached and refreshed in the background rather than queried per keystroke.
