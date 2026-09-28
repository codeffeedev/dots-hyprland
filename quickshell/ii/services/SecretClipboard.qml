pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Hardened clipboard path for sensitive values.
 *
 * Rules enforced here (see openspec specs/secret-clipboard):
 *   1. Secrets never appear in any process's argument vector. `/proc/<pid>/cmdline`
 *      is world-readable; `/proc/<pid>/environ` is 0400 owner-only. Values therefore
 *      travel by environment or by pipe, never as arguments.
 *   2. Secrets never enter this shell's memory. The value is produced, buffered and
 *      emitted entirely inside a child bash process; QML attaches no stdout parser.
 *   3. Every write sets the Wayland sensitive hint, so `wl-paste --watch` reports
 *      CLIPBOARD_STATE=sensitive and cliphist declines to persist the entry.
 *   4. On failure the clipboard is left untouched.
 *
 * This service knows nothing about Bitwarden; it takes a command and copies its output.
 */
Singleton {
    id: root

    signal copySucceeded(string label)
    signal copyFailed(string label, string reason)

    readonly property var options: Config.options?.search?.bitwarden ?? null
    readonly property string clearMode: root.options?.sensitiveClearMode ?? "timeout"
    readonly property int clearSeconds: root.options?.sensitiveClearSeconds ?? 30
    readonly property bool notifyOnCopy: root.options?.notifyOnCopy ?? true

    // Exit codes emitted by the wrapper below.
    readonly property int exitProducerFailed: 10
    readonly property int exitEmptyValue: 11
    readonly property int exitClipboardLost: 12

    /**
     * bash wrapper. Runs the producer command given in "$@", buffers its output in a
     * shell variable, then emits it through the `printf` *builtin* -- a builtin forks
     * no process, so the value never reaches an argument vector.
     *
     * Buffering is deliberate. Piping the producer straight into wl-copy runs both
     * concurrently, so a failing producer still closes the pipe and wl-copy would
     * overwrite the clipboard with an empty value. Buffering lets us abort first.
     *
     * The clear guard needs no copy of the secret: `wl-copy --foreground` is itself the
     * selection owner and exits on its own the moment any other client takes the
     * selection. Killing that pid later therefore clears the clipboard only if our value
     * is still the current one. The comm check guards against pid reuse.
     */
    readonly property string copyWrapper: `
set -o pipefail
value=$("$@") || exit ${root.exitProducerFailed}
[ -n "$value" ] || exit ${root.exitEmptyValue}
printf '%s' "$value" | wl-copy --foreground --sensitive --trim-newline $WL_COPY_EXTRA_ARGS >/dev/null 2>&1 &
wl_pid=$!
unset value
if [ "\${CLEAR_SECONDS:-0}" -gt 0 ] 2>/dev/null; then
    setsid --fork bash -c '
        sleep "$1"
        [ "$(cat /proc/"$2"/comm 2>/dev/null)" = "wl-copy" ] && kill "$2" 2>/dev/null
    ' _ "$CLEAR_SECONDS" "$wl_pid" >/dev/null 2>&1 &
fi
sleep 0.15
kill -0 "$wl_pid" 2>/dev/null || exit ${root.exitClipboardLost}
exit 0
`

    // Emits a value supplied by this shell. Passed through the environment, never argv.
    readonly property string copyLiteralWrapper: `
printf '%s' "$PLAIN_VALUE" | wl-copy --foreground --sensitive --trim-newline $WL_COPY_EXTRA_ARGS >/dev/null 2>&1 &
wl_pid=$!
if [ "\${CLEAR_SECONDS:-0}" -gt 0 ] 2>/dev/null; then
    setsid --fork bash -c '
        sleep "$1"
        [ "$(cat /proc/"$2"/comm 2>/dev/null)" = "wl-copy" ] && kill "$2" 2>/dev/null
    ' _ "$CLEAR_SECONDS" "$wl_pid" >/dev/null 2>&1 &
fi
sleep 0.15
kill -0 "$wl_pid" 2>/dev/null || exit ${root.exitClipboardLost}
exit 0
`

    readonly property string wlCopyExtraArgs: root.clearMode === "pasteOnce" ? "--paste-once" : ""
    readonly property int effectiveClearSeconds: root.clearMode === "timeout" ? Math.max(0, root.clearSeconds) : 0

    function describeFailure(exitCode) {
        if (exitCode === root.exitProducerFailed)
            return Translation.tr("the vault command failed");
        if (exitCode === root.exitEmptyValue)
            return Translation.tr("there was nothing to copy");
        if (exitCode === root.exitClipboardLost)
            return Translation.tr("the clipboard rejected the value");
        return Translation.tr("exit code %1").arg(exitCode);
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", summary, body, "-a", "Shell"]);
    }

    /**
     * Copies the stdout of `argv` to the clipboard as a secret.
     * @param argv list<string> producer command; MUST NOT contain the secret itself
     * @param environment object extra env for the producer (e.g. BW_SESSION)
     * @param label string human-readable item name, used only for notifications
     */
    function copyFromCommand(argv, environment, label) {
        const env = Object.assign({}, environment ?? {}, {
            CLEAR_SECONDS: String(root.effectiveClearSeconds),
            WL_COPY_EXTRA_ARGS: root.wlCopyExtraArgs
        });
        copyProc.pendingLabel = label ?? "";
        copyProc.exec({
            environment: env,
            command: ["bash", "-c", root.copyWrapper, "_"].concat(argv)
        });
    }

    /**
     * Copies a value already held by the shell (e.g. a username). Still marked sensitive
     * so that clipboard history stays free of credential material.
     */
    function copyText(value, label) {
        copyProc.pendingLabel = label ?? "";
        copyProc.exec({
            environment: {
                PLAIN_VALUE: String(value),
                CLEAR_SECONDS: String(root.effectiveClearSeconds),
                WL_COPY_EXTRA_ARGS: root.wlCopyExtraArgs
            },
            command: ["bash", "-c", root.copyLiteralWrapper]
        });
    }

    Process {
        id: copyProc
        property string pendingLabel: ""
        // No stdout parser is attached, by design: the secret must not reach QML.

        onExited: (exitCode, exitStatus) => {
            const label = copyProc.pendingLabel;
            copyProc.pendingLabel = "";
            if (exitCode === 0) {
                root.copySucceeded(label);
                if (root.notifyOnCopy) {
                    root.notify(Translation.tr("Copied"), root.effectiveClearSeconds > 0 ? Translation.tr("%1 — clipboard clears in %2s").arg(label).arg(root.effectiveClearSeconds) : label);
                }
            } else {
                const reason = root.describeFailure(exitCode);
                root.copyFailed(label, reason);
                root.notify(Translation.tr("Copy failed"), Translation.tr("%1: %2").arg(label).arg(reason));
            }
        }
    }
}
