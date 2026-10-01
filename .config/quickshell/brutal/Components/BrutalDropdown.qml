import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config

/**
 * A closed list of choices: a BrutalButton showing the current one, which
 * opens a panel of rows.
 *
 * The panel is a PopupWindow rather than an Item in the scene because every
 * settings pane puts its controls inside a clipped Flickable, and a list
 * drawn in-scene is cut off at the panel edge exactly when it opens
 * downwards — which is always. A separate surface has no such ceiling.
 *
 * Rows follow the tray menu: transparent fills, so the ink they inherit is
 * measured against the panel behind them rather than against nothing.
 */
BrutalButton {
    id: root

    /// The choices, as plain strings.
    property var model: []
    property int currentIndex: 0

    readonly property int count: root.model ? root.model.length : 0
    readonly property string currentText: (root.currentIndex >= 0 && root.currentIndex < root.count)
        ? root.model[root.currentIndex]
        : ""

    /// Raised when a row is chosen. The consumer owns `currentIndex` and is
    /// expected to move it, usually by letting its existing binding
    /// re-evaluate — assigning it here instead would overwrite that binding
    /// the first time anyone picked something, and the control would then
    /// stop following the thing it is meant to be displaying.
    signal activated(int index)

    function close(): void { panel.visible = false; }

    implicitHeight: 36
    radius: Theme.radius.sm
    enabled: root.count > 0

    onClicked: panel.visible = !panel.visible

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space.md
        anchors.rightMargin: Theme.space.sm
        spacing: Theme.space.sm

        BrutalText {
            Layout.fillWidth: true
            text: root.currentText
            elide: Text.ElideRight
            font.family: Theme.font.mono
        }

        BrutalIcon {
            text: Icons.chevronDown
            font.pixelSize: Theme.font.icon.xs
            rotation: panel.visible ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.curve }
            }
        }
    }

    PopupWindow {
        id: panel

        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: Theme.space.xs

        color: "transparent"
        visible: false
        // Closes the panel when the pointer goes anywhere else.
        grabFocus: true

        implicitWidth: root.width + Theme.shadow.md
        implicitHeight: sheet.implicitHeight + Theme.shadow.md

        BrutalBox {
            id: sheet

            anchors.left: parent.left
            anchors.top: parent.top
            implicitWidth: root.width
            implicitHeight: rows.implicitHeight + Theme.space.sm * 2

            color: Theme.color.base
            radius: Theme.radius.md
            shadowOffset: Theme.shadow.md

            ColumnLayout {
                id: rows

                anchors.fill: parent
                anchors.margins: Theme.space.sm
                spacing: 2

                Repeater {
                    model: root.model

                    delegate: BrutalButton {
                        id: row

                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: Theme.radius.xs
                        shadowed: false
                        border.width: 0
                        baseColor: row.index === root.currentIndex ? Theme.color.crust : "transparent"
                        hoverColor: Theme.color.crust

                        onClicked: {
                            panel.visible = false;
                            if (row.index === root.currentIndex) return;
                            root.activated(row.index);
                        }

                        BrutalText {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space.sm
                            anchors.rightMargin: Theme.space.sm
                            verticalAlignment: Text.AlignVCenter
                            text: row.modelData
                            elide: Text.ElideRight
                            font.family: Theme.font.mono
                        }
                    }
                }
            }
        }
    }
}
