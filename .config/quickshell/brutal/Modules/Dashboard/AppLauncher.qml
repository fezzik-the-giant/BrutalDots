import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Components
import qs.Services

/// Vertical list of the user's configured applications.
BrutalCard {
    id: root

    padding: Theme.space.xl

    /**
     * Name the row after the program it actually launches, so a rail configured
     * with spotify and discord reads "Spotify" and "Discord" rather than
     * "Music" and "Chat". Falls back to the generic label when the setting is
     * empty or is a shell line too tangled to name (`sh -c '…'`).
     */
    function label(cmd: string, fallback: string): string {
        // A command picked in Settings is a full Exec line — `flatpak run …`
        // would otherwise be named "Flatpak".
        const entry = Apps.entryForCommand(cmd);
        if (entry) return entry.name;
        const word = (cmd ?? "").trim().split(/\s+/)[0] ?? "";
        const name = word.split("/").pop();
        if (name === "" || !/^[A-Za-z][A-Za-z0-9._-]*$/.test(name)) return fallback;
        const stem = name.replace(/\.(sh|desktop|AppImage)$/i, "");
        return stem.charAt(0).toUpperCase() + stem.slice(1);
    }

    // Two colours per row, because the row uses its colour twice and the two
    // uses want opposite ends of the ramp: `tint` fills the whole button on
    // hover, `mark` is the glyph drawn on the unhovered fill. In light mode
    // they are the same pastel; after dark they are not.
    readonly property var entries: [
        { label: root.label(Settings.data.apps.browser,  "Browser"),  icon: Icons.browser,  tint: Theme.color.coral,    mark: Theme.mark.coral,    cmd: Settings.data.apps.browser },
        { label: root.label(Settings.data.apps.terminal, "Terminal"), icon: Icons.terminal, tint: Theme.color.green,    mark: Theme.mark.green,    cmd: Settings.data.apps.terminal },
        { label: root.label(Settings.data.apps.files,    "Files"),    icon: Icons.files,    tint: Theme.color.peach,    mark: Theme.mark.peach,    cmd: Settings.data.apps.files },
        { label: root.label(Settings.data.apps.music,    "Music"),    icon: Icons.music,    tint: Theme.color.mint,     mark: Theme.mark.mint,     cmd: Settings.data.apps.music },
        { label: root.label(Settings.data.apps.editor,   "Editor"),   icon: Icons.editor,   tint: Theme.color.blue,     mark: Theme.mark.blue,     cmd: Settings.data.apps.editor },
        { label: root.label(Settings.data.apps.chat,     "Chat"),     icon: Icons.chat,     tint: Theme.color.lavender, mark: Theme.mark.lavender, cmd: Settings.data.apps.chat }
    ]

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.space.md

        Repeater {
            model: root.entries

            delegate: BrutalButton {
                id: entry

                required property var modelData

                Layout.fillWidth: true
                // Share the rail's height out evenly rather than packing to the
                // top: the rail is as tall as the whole dashboard, and six
                // buttons bunched under the profile card leave a dead column.
                Layout.fillHeight: true
                Layout.minimumHeight: 40
                implicitHeight: 46
                radius: Theme.radius.sm
                shadowOffset: Theme.shadow.sm
                hoverColor: entry.modelData.tint

                onClicked: {
                    Apps.runApp(entry.modelData.cmd);
                    ShellState.dashboardOpen = false;
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.lg
                    anchors.rightMargin: Theme.space.lg
                    spacing: Theme.space.md

                    BrutalIcon {
                        // Tinted rather than ink: at this size the glyph is the
                        // only thing telling the six rows apart at a glance.
                        text: entry.modelData.icon
                        color: Qt.darker(entry.modelData.mark, 1.25)
                        font.pixelSize: Theme.font.icon.xl
                    }

                    BrutalText {
                        text: entry.modelData.label
                        font.pixelSize: Theme.font.size.lg
                        font.weight: Theme.font.weight.bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
