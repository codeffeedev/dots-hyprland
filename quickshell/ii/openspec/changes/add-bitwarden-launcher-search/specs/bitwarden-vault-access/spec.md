## ADDED Requirements

### Requirement: Vault state is observable

The shell SHALL expose the Bitwarden vault's state as one of `unavailable`, `unauthenticated`, `locked`, or `unlocked`, and SHALL keep that state current without the user restarting the shell.

#### Scenario: CLI is not installed

- **WHEN** the `bw` executable cannot be found on `PATH`
- **THEN** the vault state SHALL be `unavailable`
- **AND** no vault process SHALL be spawned on subsequent queries

#### Scenario: User has never logged in

- **WHEN** `bw status` reports `"status": "unauthenticated"`
- **THEN** the vault state SHALL be `unauthenticated`

#### Scenario: Vault is locked

- **WHEN** `bw status` reports `"status": "locked"`
- **THEN** the vault state SHALL be `locked`
- **AND** the cached item index SHALL be discarded

#### Scenario: Session becomes invalid while the shell is running

- **WHEN** a vault command fails because the session key is rejected
- **THEN** the vault state SHALL transition to `locked`
- **AND** the cached session key SHALL be discarded

### Requirement: Session keys never touch disk or process arguments

The session key returned by `bw unlock --raw` SHALL be held only in shell memory and SHALL be passed to child processes exclusively through the `BW_SESSION` environment variable.

#### Scenario: Passing the session to a vault command

- **WHEN** the shell invokes any `bw` subcommand that requires an unlocked vault
- **THEN** the session key SHALL be supplied via the child process environment
- **AND** the session key SHALL NOT appear in the child process's argument vector
- **AND** the session key SHALL NOT be written to any file, log, or config

#### Scenario: Shell restarts

- **WHEN** the shell process exits or reloads
- **THEN** the cached session key SHALL be lost
- **AND** the vault state SHALL be re-derived from `bw status` on next use

### Requirement: Non-interactive unlock from the keyring

When a Bitwarden master password is stored in the system keyring, the shell SHALL be able to unlock the vault without prompting, and SHALL pass that password to `bw` only through an environment variable.

#### Scenario: Master password present in keyring

- **WHEN** an unlock is requested and the keyring holds a master password for the configured Bitwarden account
- **THEN** the shell SHALL run `bw unlock --raw --passwordenv <VAR>` with the password supplied in that environment variable
- **AND** on success the returned session key SHALL be cached in memory
- **AND** the vault state SHALL become `unlocked`

#### Scenario: Master password absent from keyring

- **WHEN** an unlock is requested and no master password is stored
- **THEN** the shell SHALL NOT attempt a non-interactive unlock
- **AND** the user SHALL be offered an explicit unlock action

#### Scenario: Stored master password is wrong

- **WHEN** a non-interactive unlock fails authentication
- **THEN** the vault state SHALL remain `locked`
- **AND** the failure SHALL be surfaced to the user
- **AND** the shell SHALL NOT retry automatically

### Requirement: The item index excludes secrets

The shell SHALL maintain an index of vault items containing only non-secret fields, and SHALL NOT hold passwords, TOTP seeds, card numbers, secure notes, or custom field values in shell memory.

#### Scenario: Building the index

- **WHEN** the item index is refreshed from an unlocked vault
- **THEN** each indexed entry SHALL contain at most the item `id`, `name`, login username, login URIs, and a boolean indicating whether a TOTP seed exists
- **AND** no other field of the vault item SHALL be retained

#### Scenario: Vault locks

- **WHEN** the vault state leaves `unlocked`
- **THEN** the item index SHALL be cleared

### Requirement: Secrets are fetched on demand

A secret SHALL be read from the vault only at the moment the user acts on it, and SHALL NOT be pre-fetched, cached, or retained after the action completes.

#### Scenario: User copies a password

- **WHEN** the user triggers the copy action for an indexed item
- **THEN** the shell SHALL fetch that single item's password from `bw` at that moment
- **AND** the password SHALL NOT be stored in any shell property or variable after the copy completes

#### Scenario: User copies a TOTP code

- **WHEN** the user triggers the TOTP action for an item whose index entry records a TOTP seed
- **THEN** the shell SHALL generate the current code via `bw` at that moment
- **AND** the code SHALL NOT be retained after the copy completes

### Requirement: Index refresh is decoupled from typing

The shell SHALL serve launcher queries from the cached index and SHALL NOT invoke the `bw` CLI in response to individual keystrokes.

#### Scenario: User types in the launcher

- **WHEN** the user types characters into a vault-prefixed launcher query
- **THEN** results SHALL be produced by matching against the cached index
- **AND** no `bw` process SHALL be spawned for the keystroke

#### Scenario: Index is stale or missing

- **WHEN** a vault query is made and no index has been built during the current unlocked session
- **THEN** the shell SHALL start a background index refresh
- **AND** SHALL indicate that results are loading rather than reporting an empty vault

### Requirement: Vault synchronisation is explicit or scheduled

The shell SHALL support pulling remote vault changes via `bw sync`, either on a configured interval or on user request, and SHALL refresh the item index afterwards.

#### Scenario: User requests a sync

- **WHEN** the user triggers the vault sync action
- **THEN** the shell SHALL run `bw sync` against the unlocked vault
- **AND** SHALL rebuild the item index when the sync succeeds

#### Scenario: Sync fails while offline

- **WHEN** `bw sync` fails because the server is unreachable
- **THEN** the previously cached index SHALL remain usable
- **AND** the failure SHALL be surfaced without clearing the vault state
