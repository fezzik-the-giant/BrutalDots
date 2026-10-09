import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Config
import qs.Components
import qs.Services

/// Notification history, opened from the bar's bell.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        readonly property bool onFocusedMonitor: Hyprland.focusedMonitor
            ? Hyprland.focusedMonitor.name === win.modelData.name
            : true

        screen: win.modelData
        visible: ShellState.notificationsOpen && win.onFocusedMonitor
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "brutaldots-notification-panel"

        // Click-away target. Left transparent so the desktop stays readable —
        // this is a side panel, not a modal.
        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.notificationsOpen = false
        }

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: ShellState.notificationsOpen = false

            BrutalBox {
                id: panel

                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: Theme.space.md
                    rightMargin: Settings.data.bar.sideMargin + Theme.shadow.lg
                }
                implicitWidth: 400
                implicitHeight: Math.min(win.height * 0.7, layout.implicitHeight + Theme.space.lg * 2)
                color: Theme.color.mantle
                radius: Theme.radius.xl
                shadowOffset: Theme.shadow.lg

                scale: ShellState.notificationsOpen ? 1 : 0.97
                Behavior on scale { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.curve } }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Theme.space.lg
                    spacing: Theme.space.md

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space.sm

                        BrutalIcon {
                            text: Icons.bell
                            font.pixelSize: Theme.font.size.md
                        }

                        BrutalText {
                            text: "Notifications"
                            font.pixelSize: Theme.font.size.md
                            font.weight: Theme.font.weight.bold
                            Layout.fillWidth: true
                        }

                        BrutalPill {
                            text: `${Notifications.count}`
                            color: Theme.color.base
                            fontSize: Theme.font.size.xs
                            hPadding: Theme.space.sm
                        }

                        BrutalIconButton {
                            icon: Notifications.doNotDisturb ? Icons.bellOff : Icons.bell
                            size: 26
                            radius: Theme.radius.sm
                            baseColor: Notifications.doNotDisturb ? Theme.color.peach : Theme.color.base
                            hoverColor: Theme.color.peach
                            onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
                        }

                        BrutalIconButton {
                            icon: Icons.trash
                            size: 26
                            radius: Theme.radius.sm
                            hoverColor: Theme.color.red
                            visible: Notifications.count > 0
                            onClicked: Notifications.clearAll()
                        }
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Notifications.count > 0
                        implicitHeight: Math.min(contentHeight, 460)
                        clip: true
                        spacing: Theme.space.md
                        model: Notifications.list
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: NotificationItem {
                            required property var modelData

                            width: ListView.view.width
                            notification: modelData
                            onDismissed: Notifications.dismiss(modelData)
                        }
                    }

                    BrutalText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.space.lg
                        Layout.bottomMargin: Theme.space.lg
                        visible: Notifications.count === 0
                        text: "Nothing here."
                        dim: true
                        font.pixelSize: Theme.font.size.sm
                    }
                }
            }
        }
    }
}
