pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

/**
 * Sets the GTK colour scheme so applications follow the shell's dark mode.
 *
 * Really only sets `color-scheme`; the portal republishes it to Qt, Electron
 * and Firefox. `gtk-theme` is adjusted too, but only between installed
 * variants of whatever theme is already set. Turn the whole thing off with
 * `theme.syncApps` in settings.json.
 *
 * shell.qml calls `sync`; see AGENTS.md for why the trigger lives there.
 */
Singleton {
    id: root

    readonly property bool enabled: Settings.data.theme.syncApps

    // A sync that lands while one is running is replayed when it exits,
    // rather than dropped: the dropped one would be the newer value.
    property bool pending: false

    /// Point GTK — and through the portal, most of the rest — at the palette
    /// the shell is currently wearing.
    function sync(): void {
        if (!root.enabled) return;
        if (sync_.running) { root.pending = true; return; }
        sync_.mode = Theme.dark ? "dark" : "light";
        sync_.running = true;
    }

    Process {
        id: sync_

        property string mode: "light"

        // `|| exit 0` on the guard rather than a failure: a machine with no
        // gsettings is a machine with no GTK to keep in step, not an error.
        command: ["sh", "-c",
            `mode="${sync_.mode}"; `
            + 'command -v gsettings >/dev/null 2>&1 || exit 0; '
            + 'iface="org.gnome.desktop.interface"; '
            + 'if [ "$mode" = dark ]; then scheme=prefer-dark; else scheme=prefer-light; fi; '
            + 'gsettings set "$iface" color-scheme "$scheme" || exit 1; '
            // Follow the theme already in use instead of naming one.
            + 'cur=$(gsettings get "$iface" gtk-theme 2>/dev/null | tr -d "\'"); '
            + '[ -n "$cur" ] || exit 0; '
            + 'base=${cur%-dark}; base=${base%-Dark}; '
            + 'if [ "$mode" = dark ]; then set -- "$base-dark" "$base-Dark"; else set -- "$base"; fi; '
            + 'for want in "$@"; do '
            +   '[ "$want" = "$cur" ] && exit 0; '
            +   'for d in "$HOME/.themes" "$HOME/.local/share/themes" /usr/share/themes; do '
            +     'if [ -d "$d/$want" ]; then '
            +       'gsettings set "$iface" gtk-theme "$want"; exit 0; '
            +     'fi; '
            +   'done; '
            + 'done; '
            // No counterpart installed. color-scheme is still set, which is
            // what anything modern actually reads.
            + 'exit 0']

        stderr: StdioCollector { id: syncErr }
        onExited: code => {
            if (code !== 0) {
                console.warn("Toolkit: could not update the GTK colour scheme -",
                    syncErr.text.trim() || `exit ${code}`);
            }
            if (root.pending) {
                root.pending = false;
                Qt.callLater(root.sync);
            }
        }
    }
}
