import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Components
import qs.Services

/// Row of coloured bookmark tiles, driven entirely by settings.json.
BrutalCard {
    id: root

    padding: Theme.space.lg

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space.md

        Repeater {
            model: Settings.data.quickLinks

            delegate: BrutalButton {
                id: tile

                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: 96
                radius: Theme.radius.sm
                baseColor: Theme.named(tile.modelData.color ?? "")
                hoverColor: Qt.lighter(tile.baseColor, 1.08)

                onClicked: {
                    // A link just added in Settings has no URL yet.
                    if (!tile.modelData.url) return;
                    Quickshell.execDetached(["xdg-open", tile.modelData.url]);
                    ShellState.dashboardOpen = false;
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.space.xs

                    BrutalIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.named(tile.modelData.icon ?? "")
                        font.pixelSize: Theme.font.icon.xl
                    }

                    BrutalText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.name ?? ""
                        font.pixelSize: Theme.font.size.sm
                        font.weight: Theme.font.weight.bold
                    }
                }
            }
        }
    }
}
