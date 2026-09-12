import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services

/// The dashboard's pane switcher. Two segments, the active one filled.
RowLayout {
    id: root

    spacing: Theme.space.md

    readonly property var tabs: [
        { key: "overview", label: "Overview", icon: Icons.dashboard, tint: Theme.color.peach },
        { key: "settings", label: "Settings", icon: Icons.settings,  tint: Theme.color.blue },
        { key: "keybinds", label: "Keybinds", icon: Icons.keyboard,  tint: Theme.color.mint },
        { key: "monitors", label: "Monitors", icon: Icons.monitor,   tint: Theme.color.lavender }
    ]

    Repeater {
        model: root.tabs

        delegate: BrutalButton {
            id: tab

            required property var modelData

            readonly property bool active: ShellState.dashboardTab === tab.modelData.key

            implicitWidth: label.implicitWidth + icon.implicitWidth
                + Theme.space.sm + Theme.space.xl * 2
            implicitHeight: 40
            radius: Theme.radius.sm
            // The active tab is pressed into the page: filled, and with its
            // shadow gone, so it reads as the surface you are already on.
            shadowed: !tab.down && !tab.active
            baseColor: tab.active ? tab.modelData.tint : Theme.color.base
            hoverColor: tab.modelData.tint

            onClicked: ShellState.dashboardTab = tab.modelData.key

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.space.sm

                BrutalIcon {
                    id: icon
                    text: tab.modelData.icon
                    font.pixelSize: Theme.font.icon.sm
                }

                BrutalText {
                    id: label
                    text: tab.modelData.label
                    font.pixelSize: Theme.font.size.md
                    font.weight: Theme.font.weight.bold
                }
            }
        }
    }

    Item { Layout.fillWidth: true }
}
