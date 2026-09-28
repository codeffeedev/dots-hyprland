## ADDED Requirements

### Requirement: A dedicated launcher prefix routes to the vault

The launcher SHALL recognise a configurable prefix that routes the remainder of the query to vault search, consistent with the existing app, clipboard, emoji, math, command and web-search prefixes.

#### Scenario: Query begins with the vault prefix

- **WHEN** the launcher query begins with the configured vault prefix
- **THEN** the results SHALL consist solely of vault results
- **AND** app, math, command and web-search results SHALL be suppressed

#### Scenario: Switching between prefixes

- **WHEN** the user switches an existing query to the vault prefix through the prefix-switching helper
- **THEN** the previous prefix SHALL be replaced rather than appended

#### Scenario: Feature disabled

- **WHEN** the vault integration is disabled in configuration
- **THEN** the vault prefix SHALL NOT produce vault results
- **AND** the query SHALL be handled as an ordinary launcher query

#### Scenario: Vault results never leak into unprefixed search

- **WHEN** the user types a query without the vault prefix
- **THEN** no vault item SHALL appear in the results

### Requirement: Fuzzy matching spans name, username and URI

Vault search SHALL fuzzy-match the query against each indexed item's name, login username and login URIs, using the same matching behaviour as the launcher's other providers.

#### Scenario: Matching by item name

- **WHEN** the query text fuzzy-matches an item's name
- **THEN** that item SHALL appear in the results

#### Scenario: Matching by username

- **WHEN** the query text fuzzy-matches an item's login username
- **THEN** that item SHALL appear in the results

#### Scenario: Matching by site

- **WHEN** the query text fuzzy-matches the host of one of an item's login URIs
- **THEN** that item SHALL appear in the results

#### Scenario: Empty query

- **WHEN** the query consists of the vault prefix alone
- **THEN** the results SHALL list indexed items without filtering

### Requirement: Results identify items without revealing secrets

Each vault result SHALL display enough to disambiguate the item and SHALL NOT display any secret value.

#### Scenario: Rendering a result

- **WHEN** a vault item is presented as a launcher result
- **THEN** the result SHALL show the item name and its login username
- **AND** the result SHALL NOT show the password, TOTP code, or any other secret field

### Requirement: The primary action copies the password

Activating a vault result SHALL copy that item's password through the secret clipboard path.

#### Scenario: User activates a result

- **WHEN** the user activates a vault result
- **THEN** the item's password SHALL be copied using the secret clipboard path
- **AND** the launcher SHALL close

#### Scenario: Item has no password

- **WHEN** the activated item has no password field
- **THEN** the clipboard SHALL NOT be modified
- **AND** the user SHALL be told the item has no password

### Requirement: Secondary actions cover username, TOTP and URI

Each vault result SHALL offer secondary actions alongside the primary copy, following the launcher's existing result-action pattern.

#### Scenario: Copying the username

- **WHEN** the user triggers the copy-username action
- **THEN** the login username SHALL be placed on the clipboard

#### Scenario: Copying a TOTP code

- **WHEN** the user triggers the TOTP action on an item whose index entry records a TOTP seed
- **THEN** the current code SHALL be copied through the secret clipboard path

#### Scenario: TOTP unavailable

- **WHEN** an item has no TOTP seed
- **THEN** the TOTP action SHALL NOT be offered for that item

#### Scenario: Opening the item's site

- **WHEN** the user triggers the open-URI action on an item with at least one login URI
- **THEN** the first URI SHALL be opened in the default browser

### Requirement: Locked and unavailable vaults are actionable, not silent

When the vault cannot serve results, the launcher SHALL explain why and offer the corrective action instead of returning an empty list.

#### Scenario: Vault is locked

- **WHEN** a vault query is made while the vault is locked
- **THEN** a single result SHALL be shown offering to unlock the vault
- **AND** activating it SHALL trigger the unlock flow

#### Scenario: Unlock succeeds from the launcher

- **WHEN** the unlock triggered from the launcher succeeds
- **THEN** the item index SHALL be built
- **AND** the pending query SHALL be re-evaluated against the new index

#### Scenario: User is not logged in

- **WHEN** a vault query is made while the vault is unauthenticated
- **THEN** a single result SHALL explain that a Bitwarden login is required

#### Scenario: CLI is missing

- **WHEN** a vault query is made while the `bw` CLI is unavailable
- **THEN** a single result SHALL state that `bitwarden-cli` is not installed

### Requirement: Vault maintenance actions are reachable from the launcher

The launcher's action prefix SHALL expose vault lock and vault sync actions.

#### Scenario: Locking from the launcher

- **WHEN** the user runs the vault lock action
- **THEN** the vault SHALL be locked
- **AND** the cached session key and item index SHALL be discarded

#### Scenario: Syncing from the launcher

- **WHEN** the user runs the vault sync action
- **THEN** a vault synchronisation SHALL be started
- **AND** the user SHALL be notified when it completes
