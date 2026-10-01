import QtQuick
import qs.Config

/// Square tick box with the same border/shadow treatment as everything else.
BrutalBox {
    id: root

    property bool checked: false
    property int size: 22
    property color checkColor: Theme.color.green

    signal toggled(bool checked)

    implicitWidth: root.size
    implicitHeight: root.size
    radius: Theme.radius.xs
    color: root.checked ? root.checkColor : Theme.color.base
    shadowOffset: Theme.shadow.sm
    shadowed: !mouse.containsPress

    Behavior on color { ColorAnimation { duration: Theme.anim.fast } }

    BrutalIcon {
        anchors.centerIn: parent
        text: Icons.check
        font.pixelSize: root.size * 0.7
        opacity: root.checked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Emitting toggled without assigning preserves external bindings.
            root.toggled(!root.checked);
        }
    }
}
