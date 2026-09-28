## ADDED Requirements

### Requirement: Secrets are excluded from clipboard history

Clipboard writes performed through the secret path SHALL be marked sensitive so that the running `cliphist` watcher does not persist them.

#### Scenario: Copying a password

- **WHEN** a secret is written to the clipboard through the secret path
- **THEN** the write SHALL set the Wayland sensitive-content hint
- **AND** the clipboard watcher SHALL receive `CLIPBOARD_STATE=sensitive`
- **AND** no corresponding entry SHALL be added to the clipboard history database

#### Scenario: Secret is not retrievable from the clipboard prefix afterwards

- **WHEN** the user searches clipboard history with the clipboard prefix after copying a secret
- **THEN** the copied secret SHALL NOT appear among the results

#### Scenario: Ordinary clipboard copies are unaffected

- **WHEN** a non-secret value is copied through the existing clipboard path
- **THEN** it SHALL continue to be recorded in clipboard history as before

### Requirement: Secrets never appear in process arguments

A secret value SHALL NOT be placed in the argument vector of any process, because argument vectors are world-readable through `/proc`.

#### Scenario: Building the copy pipeline

- **WHEN** the shell constructs the command that copies a secret
- **THEN** the secret SHALL be transferred from the producing process to the clipboard process through a pipe or standard input
- **AND** only non-secret identifiers, such as the vault item id, MAY appear as arguments

#### Scenario: Secret-bearing command inspected externally

- **WHEN** another process on the system reads the command line of any process spawned during a secret copy
- **THEN** it SHALL NOT observe the secret value

### Requirement: Secrets do not enter shell memory

Where the value is produced by a child process, the secret SHALL be streamed directly to the clipboard without being read into the shell's own memory.

#### Scenario: Copying a vault password

- **WHEN** a vault password is copied
- **THEN** the producing process's standard output SHALL be connected to the clipboard process's standard input
- **AND** the shell SHALL NOT parse, buffer, or assign the secret value

### Requirement: Clipboard retention of secrets is bounded

A secret placed on the clipboard SHALL NOT remain available indefinitely.

#### Scenario: Default single-paste retention

- **WHEN** a secret is copied and the configured retention mode is single-paste
- **THEN** the clipboard offer SHALL be withdrawn after the first paste

#### Scenario: Timed retention

- **WHEN** a secret is copied and a clearing timeout is configured
- **THEN** the clipboard SHALL be cleared after that timeout elapses
- **AND** the clipboard SHALL NOT be cleared if its contents have since been replaced by a different value

#### Scenario: Retention disabled

- **WHEN** the user has explicitly disabled automatic clearing
- **THEN** the secret SHALL remain on the clipboard until replaced
- **AND** it SHALL still be excluded from clipboard history

### Requirement: Copy outcome is reported without disclosing the secret

The user SHALL receive confirmation that a secret was copied, and that confirmation SHALL NOT contain the secret.

#### Scenario: Successful copy

- **WHEN** a secret copy succeeds
- **THEN** the user SHALL be notified referring to the item by name only

#### Scenario: Failed copy

- **WHEN** the producing command exits non-zero or yields no output
- **THEN** the clipboard SHALL NOT be modified
- **AND** the user SHALL be notified that the copy failed
