import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Config
import qs.Components
import qs.Services
import qs.Modules.Common

/**
 * The full-screen control centre.
 *
 * One overlay surface per monitor, holding a scrim and the panel. Clicking the
 * scrim or pressing Escape closes it.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        readonly property bool onFocusedMonitor: Hyprland.focusedMonitor
            ? Hyprland.focusedMonitor.name === win.modelData.name
            : true

        screen: win.modelData
        visible: ShellState.dashboardOpen && win.onFocusedMonitor
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "brutaldots-dashboard"

        // ── Scrim ──────────────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: Theme.color.overlay

            MouseArea {
                anchors.fill: parent
                onClicked: ShellState.dashboardOpen = false
            }
        }

        // ── Panel ──────────────────────────────────────────────────────────
        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: ShellState.dashboardOpen = false

            BrutalBox {
                id: panel

                anchors.centerIn: parent
                // Offset by half the shadow so the panel reads as centred
                // rather than sitting half a shadow to the left.
                anchors.horizontalCenterOffset: -Theme.shadow.lg / 2
                anchors.verticalCenterOffset: -Theme.shadow.lg / 2
                implicitWidth: Math.min(1220, win.width * 0.78)
                implicitHeight: Math.min(win.height * 0.88,
                    content.implicitHeight + Theme.space.xl * 2)
                color: Theme.color.mantle
                radius: Theme.radius.xl
                shadowOffset: Theme.shadow.lg

                // Blunt, quick entrance — no float-in easing.
                scale: ShellState.dashboardOpen ? 1 : 0.97
                opacity: ShellState.dashboardOpen ? 1 : 0

                Behavior on scale { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.curve } }
                Behavior on opacity { NumberAnimation { duration: Theme.anim.normal } }

                // Swallow clicks so they don't reach the scrim.
                MouseArea { anchors.fill: parent }

                RowLayout {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Theme.space.xl
                    spacing: Theme.space.lg

                    // ── Left rail ──────────────────────────────────────────
                    ColumnLayout {
                        Layout.preferredWidth: 250
                        Layout.fillHeight: true
                        spacing: Theme.space.lg

                        ProfileCard {
                            Layout.fillWidth: true
                        }

                        // Takes the rest of the rail, and hands it out evenly
                        // among the six app rows.
                        AppLauncher {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }

                    // ── Main area ──────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.space.lg

                        TabStrip { Layout.fillWidth: true }

                        // A StackLayout rather than two `visible` siblings: it
                        // takes the size of its tallest page, so switching tabs
                        // changes what is in the panel without resizing the
                        // panel under the cursor.
                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: {
                                switch (ShellState.dashboardTab) {
                                case "settings": return 1;
                                case "keybinds": return 2;
                                case "monitors": return 3;
                                default: return 0;
                                }
                            }

                            // ── Overview ───────────────────────────────────
                            ColumnLayout {
                                spacing: Theme.space.lg

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.space.lg

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.space.lg

                                        ClockCard { Layout.fillWidth: true }

                                        EnvironmentCard {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                        }
                                    }

                                    // The three columns of the top row are all
                                    // given the row's full height so their
                                    // cards end on one line, rather than each
                                    // stopping wherever its own contents
                                    // happen to run out.
                                    LevelSliders {
                                        Layout.preferredWidth: 140
                                        Layout.fillHeight: true
                                    }

                                    SystemSpecs {
                                        Layout.preferredWidth: 400
                                        Layout.fillHeight: true
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.space.lg

                                    MediaPlayer {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        artSize: 160
                                    }

                                    ResourceMeters {
                                        Layout.preferredWidth: 250
                                        Layout.fillHeight: true
                                    }
                                }

                                QuickLinks { Layout.fillWidth: true }
                            }

                            // ── Settings ───────────────────────────────────
                            SettingsPane {}

                            // ── Keybinds ───────────────────────────────────
                            KeybindsPane {}

                            // ── Monitors ───────────────────────────────────
                            MonitorsPane {}
                        }
                    }
                }
            }
        }
    }
}
