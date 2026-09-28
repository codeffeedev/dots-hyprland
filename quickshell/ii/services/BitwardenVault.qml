pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Bitwarden vault access on top of the `bw` CLI.
 *
 * Security invariants (see openspec specs/bitwarden-vault-access):
 *   - The session key lives in one in-memory property. It is never written to disk and
 *     is handed to child processes only through BW_SESSION, because /proc/<pid>/environ
 *     is 0400 owner-only while /proc/<pid>/cmdline is world-readable.
 *   - The item index holds no secrets. `bw list items` emits the fully decrypted vault,
 *     so a jq allow-list strips it inside the pipeline; only that filtered array is ever
 *     parsed by QML. Password and TOTP presence are recorded as booleans only.
 *   - Secrets are fetched per action and streamed to the clipboard by SecretClipboard,
 *     never assigned to a property here.
 */
Singleton {
    id: root

    // "unavailable" | "unauthenticated" | "locked" | "unlocked"
    property string state: "unavailable"
    readonly property bool unlocked: root.state === "unlocked"

    property bool cliAvailable: false
    property bool indexLoading: false
    property string lastError: ""

    // The single in-memory home of the session key.
    property string session: ""

    // Secret-free item index.
    property var items: []

    readonly property var options: Config.options?.search?.bitwarden ?? null
    readonly property bool enabled: root.options?.enable ?? false
    readonly property int syncIntervalMinutes: root.options?.syncIntervalMinutes ?? 0
    readonly property bool useKeyringMasterPassword: root.options?.useKeyringMasterPassword ?? false

    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2

    signal unlockFailed(string reason)
    signal indexRefreshed
    signal syncFinished(bool ok)

    /**
     * jq allow-list. Explicitly an allow-list, never a deny-list, so fields Bitwarden
     * adds upstream are dropped by construction rather than leaking through.
     * `type == 1` selects login items; cards, identities and notes are out of scope.
     * `hasPassword` and `totp` are booleans - presence flags, not the values.
     */
    readonly property string indexFilter: '[.[] | select(.type == 1) | {id, name, username: (.login.username // ""), uris: [.login.uris[]?.uri // empty], totp: ((.login.totp // "") != ""), hasPassword: ((.login.password // "") != "")}]'

    function envWithSession(extra) {
        const env = Object.assign({
            LANG: "C",
            LC_ALL: "C",
            BW_NOINTERACTION: "true"
        }, extra ?? {});
        if (root.session.length > 0)
            env.BW_SESSION = root.session;
        return env;
    }

    function setState(next) {
        if (root.state === next)
            return;
        root.state = next;
        if (next !== "unlocked") {
            root.session = "";
            root.items = [];
        }
    }

    // Called when a vault command reports a rejected session.
    function invalidateSession(reason) {
        root.session = "";
        root.items = [];
        root.state = "locked";
        root.lastError = reason ?? "";
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", summary, body, "-a", "Shell"]);
    }

    // ---------------------------------------------------------------- CLI detection

    Process {
        id: cliCheckProc
        command: ["bash", "-c", "command -v bw >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.cliAvailable = (exitCode === 0);
            if (!root.cliAvailable) {
                root.setState("unavailable");
            } else {
                root.refreshStatus();
            }
        }
    }

    function detectCli() {
        cliCheckProc.running = true;
    }

    // ------------------------------------------------------------------- bw status

    Process {
        id: statusProc
        stdout: StdioCollector {
            id: statusCollector
            onStreamFinished: {
                const raw = statusCollector.text.trim();
                if (raw.length === 0) {
                    root.setState("unavailable");
                    return;
                }
                if (raw === "unlocked") {
                    root.state = "unlocked";
                    if (root.items.length === 0 && !root.indexLoading)
                        root.refreshIndex();
                } else if (raw === "locked") {
                    root.setState("locked");
                } else if (raw === "unauthenticated") {
                    root.setState("unauthenticated");
                } else {
                    root.setState("unavailable");
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.state !== "unavailable") {
                root.lastError = Translation.tr("Could not read vault status");
            }
        }
    }

    function refreshStatus() {
        if (!root.cliAvailable)
            return;
        statusProc.exec({
            environment: root.envWithSession(),
            // `bw status` emits JSON; jq isolates the one field we act on.
            command: ["bash", "-c", "bw status 2>/dev/null | jq -r '.status // empty'"]
        });
    }

    // ------------------------------------------------------------------- unlocking

    // Keyring-backed, non-interactive. Opt-in: see the warning on the config key.
    Process {
        id: keyringUnlockProc
        stdout: StdioCollector {
            id: keyringUnlockCollector
            onStreamFinished: {
                const key = keyringUnlockCollector.text.trim();
                if (key.length > 0) {
                    root.session = key;
                    root.state = "unlocked";
                    root.lastError = "";
                    root.refreshIndex();
                    if (root.syncIntervalMinutes <= 0)
                        root.sync();
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                return;
            // Never retry automatically; a wrong stored password must not hammer the vault.
            let reason = Translation.tr("Unlock failed");
            if (exitCode === 1)
                reason = Translation.tr("No master password stored in the keyring");
            else if (exitCode === 2)
                reason = Translation.tr("The login keyring is locked");
            else if (exitCode === 3)
                reason = Translation.tr("Bitwarden rejected the stored master password");
            root.lastError = reason;
            root.state = "locked";
            root.unlockFailed(reason);
            root.notify(Translation.tr("Bitwarden"), reason);
        }
    }

    // Interactive. The typed password is held only for the duration of this call.
    Process {
        id: passwordUnlockProc
        stdout: StdioCollector {
            id: passwordUnlockCollector
            onStreamFinished: {
                const key = passwordUnlockCollector.text.trim();
                if (key.length > 0) {
                    root.session = key;
                    root.state = "unlocked";
                    root.lastError = "";
                    root.refreshIndex();
                    if (root.syncIntervalMinutes <= 0)
                        root.sync();
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                return;
            const reason = Translation.tr("Bitwarden rejected the master password");
            root.lastError = reason;
            root.state = "locked";
            root.unlockFailed(reason);
        }
    }

    /**
     * Unlocks with an explicitly supplied master password.
     * The caller MUST clear its own copy immediately after calling this.
     */
    function unlockWithPassword(masterPassword) {
        if (!root.cliAvailable)
            return;
        passwordUnlockProc.exec({
            environment: root.envWithSession({
                BW_PASSWORD: String(masterPassword)
            }),
            command: ["bash", "-c", "bw unlock --raw --passwordenv BW_PASSWORD 2>/dev/null"]
        });
    }

    /** Attempts the non-interactive keyring unlock. Returns false if not configured. */
    function unlockFromKeyring() {
        if (!root.cliAvailable || !root.useKeyringMasterPassword)
            return false;
        keyringUnlockProc.exec({
            environment: root.envWithSession(),
            command: [FileUtils.trimFileProtocol(`${Directories.scriptPath}/keyring/bw_unlock.sh`)]
        });
        return true;
    }

    /** Entry point used by the launcher. Prefers the keyring path when enabled. */
    function requestUnlock() {
        if (!root.cliAvailable) {
            root.notify(Translation.tr("Bitwarden"), Translation.tr("bitwarden-cli is not installed"));
            return;
        }
        if (root.state === "unauthenticated") {
            root.notify(Translation.tr("Bitwarden"), Translation.tr("Run `bw login` first"));
            return;
        }
        if (root.unlockFromKeyring())
            return;
        root.unlockPromptOpen = true;
        root.unlockRequested();
    }

    // Emitted when an interactive prompt is required.
    signal unlockRequested
    // Drives the interactive unlock panel.
    property bool unlockPromptOpen: false

    /**
     * Submits a master password typed by the user and immediately drops the caller's
     * obligation to keep it: the prompt clears its field as soon as this returns.
     */
    function submitUnlockPassword(masterPassword) {
        root.unlockPromptOpen = false;
        root.unlockWithPassword(masterPassword);
    }

    function cancelUnlockPrompt() {
        root.unlockPromptOpen = false;
    }

    Process {
        id: lockProc
        onExited: (exitCode, exitStatus) => {
            root.session = "";
            root.items = [];
            root.state = "locked";
        }
    }

    function lock() {
        if (!root.cliAvailable)
            return;
        lockProc.exec({
            environment: root.envWithSession(),
            command: ["bash", "-c", "bw lock >/dev/null 2>&1"]
        });
    }

    // ----------------------------------------------------------------- item index

    Process {
        id: indexProc
        stdout: StdioCollector {
            id: indexCollector
            onStreamFinished: {
                const raw = indexCollector.text.trim();
                if (raw.length === 0 || !raw.startsWith("[")) {
                    return;
                }
                try {
                    root.items = JSON.parse(raw);
                    root.indexRefreshed();
                } catch (e) {
                    console.error("[BitwardenVault] Could not parse item index");
                    root.items = [];
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.indexLoading = false;
            if (exitCode !== 0) {
                // Most often a rejected session after the vault locked elsewhere.
                root.invalidateSession(Translation.tr("Vault is locked"));
            }
        }
    }

    function refreshIndex() {
        if (!root.cliAvailable || root.state !== "unlocked")
            return;
        root.indexLoading = true;
        indexProc.exec({
            environment: root.envWithSession(),
            // The full decrypted vault never leaves this pipeline; jq strips it first.
            command: ["bash", "-c", `set -o pipefail; bw list items --nointeraction | jq -c '${root.indexFilter}'`]
        });
    }

    // ----------------------------------------------------------------------- sync

    Process {
        id: syncProc
        property bool announce: false
        onExited: (exitCode, exitStatus) => {
            const announce = syncProc.announce;
            syncProc.announce = false;
            if (exitCode === 0) {
                root.syncFinished(true);
                root.refreshIndex();
                if (announce)
                    root.notify(Translation.tr("Bitwarden"), Translation.tr("Vault synced"));
            } else {
                // Keep the cached index; an offline machine stays usable.
                root.lastError = Translation.tr("Vault sync failed");
                root.syncFinished(false);
                if (announce)
                    root.notify(Translation.tr("Bitwarden"), Translation.tr("Vault sync failed"));
            }
        }
    }

    function sync(announce = false) {
        if (!root.cliAvailable || root.state !== "unlocked")
            return;
        syncProc.announce = announce;
        syncProc.exec({
            environment: root.envWithSession(),
            command: ["bash", "-c", "bw sync >/dev/null 2>&1"]
        });
    }

    Timer {
        id: syncTimer
        running: root.enabled && root.unlocked && root.syncIntervalMinutes > 0
        interval: Math.max(1, root.syncIntervalMinutes) * 60000
        repeat: true
        onTriggered: root.sync()
    }

    // -------------------------------------------------------------------- search

    readonly property var preparedItems: root.items.map(item => ({
                // One haystack spanning name, username and URIs, matching how the other
                // launcher providers prepare their entries.
                name: Fuzzy.prepare(`${item.name} ${item.username} ${(item.uris ?? []).join(" ")}`),
                entry: item
            }))

    function fuzzyQuery(search: string): var {
        if (search.trim() === "")
            return root.items;
        if (root.sloppySearch) {
            return root.items.map(item => ({
                        entry: item,
                        score: Levendist.computeTextMatchScore(`${item.name} ${item.username}`.toLowerCase(), search.toLowerCase())
                    })).filter(i => i.score > root.scoreThreshold).sort((a, b) => b.score - a.score).map(i => i.entry);
        }
        return Fuzzy.go(search, root.preparedItems, {
            all: true,
            key: "name"
        }).map(r => r.obj.entry);
    }

    // ------------------------------------------------------------ secret actions

    function copyPassword(item) {
        if (!item)
            return;
        if (item.hasPassword === false) {
            root.notify(Translation.tr("Bitwarden"), Translation.tr("%1 has no password").arg(item.name));
            return;
        }
        SecretClipboard.copyFromCommand(["bw", "get", "password", item.id, "--nointeraction"], root.envWithSession(), item.name);
    }

    function copyTotp(item) {
        if (!item || !item.totp)
            return;
        SecretClipboard.copyFromCommand(["bw", "get", "totp", item.id, "--nointeraction"], root.envWithSession(), Translation.tr("%1 (code)").arg(item.name));
    }

    function copyUsername(item) {
        if (!item || !item.username)
            return;
        SecretClipboard.copyText(item.username, Translation.tr("%1 (username)").arg(item.name));
    }

    function openUri(item) {
        const uri = (item?.uris ?? [])[0];
        if (!uri)
            return;
        Qt.openUrlExternally(uri);
    }

    // ------------------------------------------------------------------ lifecycle

    onEnabledChanged: {
        if (root.enabled)
            root.detectCli();
    }

    Component.onCompleted: {
        if (root.enabled)
            root.detectCli();
    }
}
