#!/usr/bin/env bash
# Unlocks the Bitwarden vault using a master password held in the login keyring and
# prints ONLY the resulting session key on stdout.
#
# The master password is deliberately never printed. It is looked up here, handed to
# `bw` through an environment variable, and dies with this process. The shell that
# invokes this script therefore only ever sees the session key, which it holds in
# memory for the lifetime of the session.
#
# A dedicated attribute set is used rather than the `application=illogical-impulse`
# JSON blob that KeyringStorage maintains, because that blob is read wholesale into
# shell memory -- inappropriate for a master password.
#
# Store the password with:
#   secret-tool store --label='Bitwarden master password' \
#       application illogical-impulse service bitwarden-master
#
# Exit codes:
#   0  success, session key on stdout
#   1  no master password stored in the keyring
#   2  keyring is locked
#   3  `bw` unlock failed (wrong password, not logged in, ...)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! "${SCRIPT_DIR}/is_unlocked.sh" 2>/dev/null; then
    echo 'keyring is locked' >&2
    exit 2
fi

BW_PASSWORD=$(secret-tool lookup application illogical-impulse service bitwarden-master)
if [[ -z "${BW_PASSWORD}" ]]; then
    echo 'no master password stored in keyring' >&2
    exit 1
fi
export BW_PASSWORD

if ! bw unlock --raw --passwordenv BW_PASSWORD 2>/dev/null; then
    echo 'bw unlock failed' >&2
    exit 3
fi
