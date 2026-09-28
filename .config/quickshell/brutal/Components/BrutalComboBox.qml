import QtQuick
import QtQuick.Controls.Basic
import qs.Config

ComboBox {
    id: root
    
    font.family: Theme.font.sans
    font.pixelSize: Theme.font.size.md
    
    delegate: ItemDelegate {
        width: root.width
        contentItem: BrutalText {
            text: modelData.text || modelData
            color: Theme.color.ink
            font: root.font
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: parent.highlighted ? Theme.color.lavender : "transparent"
        }
    }

    indicator: BrutalIcon {
        x: root.width - width - root.rightPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        text: Icons.chevronDown
        color: Theme.color.ink
    }

    contentItem: BrutalText {
        leftPadding: Theme.space.md
        rightPadding: root.indicator.width + root.spacing
        text: root.displayText
        font: root.font
        color: Theme.color.ink
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: BrutalBox {
        implicitWidth: 120
        implicitHeight: 38
        radius: Theme.radius.md
        color: Theme.color.base
        shadowOffset: Theme.shadow.sm
    }

    popup: Popup {
        y: root.height - 1
        width: root.width
        implicitHeight: contentItem.implicitHeight
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: BrutalBox {
            color: Theme.color.base
            radius: Theme.radius.sm
            shadowOffset: Theme.shadow.md
        }
    }
}
