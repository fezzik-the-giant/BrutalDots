pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

/**
 * Points kitty at the palette the shell is wearing, and signals every running
 * instance so open terminals change too.
 *
 * Only acts if BrutalDots' kitty theme is actually installed. See AGENTS.md
 * for why the pointer is additive rather than naming both palettes.
 */
Singleton {
    id: root

    readonly property string kittyDir:
        (Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`)
        + "/kitty"

    // A sync that lands while one is running is replayed when it exits,
    // rather than dropped: the dropped one would be the newer value.
    property bool pending: false

    /// Point kitty at the palette the shell is currently wearing.
    function sync(): void {
        if (sync_.running) { root.pending = true; return; }
        sync_.mode = Theme.dark ? "dark" : "light";
        sync_.running = true;
    }

    Process {
        id: sync_

        property string mode: "light"

        // Light is written as the absence of an include, not as a line naming
        // the light palette: brutaldots.conf has already pulled that one in by
        // the time this file is read, and kitty treats a second include of the
        // same file as a configuration error rather than a no-op.
        //
        // `pkill` returning 1 means no kitty is running, which is not a failure
        // — the file is written either way, so the next one to start is right.
        command: ["sh", "-c",
            `dir="${root.kittyDir}"; mode="${sync_.mode}"; `
            + 'test -e "$dir/brutaldots.conf" || exit 0; '
            + '{ printf "%s\\n" '
            + '"# Which BrutalDots palette is live. Rewritten by the shell — the whole" '
            + '"# file is either this comment or this comment plus one include, so" '
            + '"# anything else you add here is lost on the next toggle." '
            + '"#" '
            + '"# brutaldots.conf has already included the light palette by the time" '
            + '"# this file is read, so light is the absence of a line and dark is:" '
            + '"#" '
            + '"#     include brutaldots-dark.conf"; '
            + 'if [ "$mode" = dark ]; then printf "%s\\n" "" "include brutaldots-dark.conf"; fi; '
            + '} > "$dir/brutaldots-mode.conf"; '
            + 'pkill -USR1 -x kitty || true']

        stderr: StdioCollector { id: syncErr }
        onExited: code => {
            if (code !== 0) {
                console.warn("Terminal: could not repoint kitty -",
                    syncErr.text.trim() || `exit ${code}`);
            }
            if (root.pending) {
                root.pending = false;
                Qt.callLater(root.sync);
            }
        }
    }
}
