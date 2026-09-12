import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Components
import qs.Services

ColumnLayout {
    id: root

    spacing: Theme.space.lg

    Component.onCompleted: {
        Monitors.displayPoller.running = true;
    }

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "transparent"
        radius: Theme.radius.sm

        Flickable {
            id: scroll
            anchors.fill: parent
            contentWidth: width
            contentHeight: column.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelScroll {}

            ColumnLayout {
                id: column
                width: parent.width
                spacing: Theme.space.lg

                // Top Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space.md

                    BrutalText {
                        text: "Monitors & Workspaces"
                        font.pixelSize: Theme.font.size.xl
                        font.weight: Theme.font.weight.bold
                        color: Theme.color.text
                        Layout.fillWidth: true
                    }

                    BrutalButton {
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 40
                        baseColor: Theme.color.green
                        hoverColor: Qt.tint(Theme.color.green, Qt.rgba(1,1,1,0.2))
                        radius: Theme.radius.sm

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.space.sm
                            BrutalIcon { text: Icons.check; color: Theme.color.crust }
                            BrutalText { text: "Apply Layout"; font.weight: Theme.font.weight.bold; color: Theme.color.crust }
                        }

                        onClicked: Monitors.applyMonitors()
                    }
                }

                // Drag Canvas
                BrutalCard {
                    id: multiMonContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    clip: true

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Dot grid background
                        Grid {
                            anchors.centerIn: parent
                            rows: 15; columns: 30; spacing: 20
                            Repeater { model: 450; Rectangle { width: 2; height: 2; radius: 1; color: Qt.alpha(Theme.color.text, 0.07) } }
                        }

                    property real targetScale: {
                        let _ = Monitors.changeTrigger;
                        if (Monitors.monitorsModel.count < 2) return 1.0;
                        let minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
                        for (let i = 0; i < Monitors.monitorsModel.count; i++) {
                            let m = Monitors.monitorsModel.get(i);
                            let isP = m.transform === 1 || m.transform === 3;
                            let w = ((isP ? m.resH : m.resW) / m.sysScale) * Monitors.uiScale;
                            let h = ((isP ? m.resW : m.resH) / m.sysScale) * Monitors.uiScale;
                            minX = Math.min(minX, m.uiX); minY = Math.min(minY, m.uiY);
                            maxX = Math.max(maxX, m.uiX + w); maxY = Math.max(maxY, m.uiY + h);
                        }
                        let requiredW = (maxX - minX) + 80;
                        let requiredH = (maxY - minY) + 80;
                        return Math.min(multiMonContainer.width / requiredW, 260 / requiredH, 1.8);
                    }
                    property real offsetX: {
                        let _ = Monitors.changeTrigger;
                        if (Monitors.monitorsModel.count < 2) return 0;
                        let minX = 999999, maxX = -999999;
                        for (let i = 0; i < Monitors.monitorsModel.count; i++) {
                            let m = Monitors.monitorsModel.get(i);
                            let isP = m.transform === 1 || m.transform === 3;
                            let w = ((isP ? m.resH : m.resW) / m.sysScale) * Monitors.uiScale;
                            minX = Math.min(minX, m.uiX); maxX = Math.max(maxX, m.uiX + w);
                        }
                        return (multiMonContainer.width / 2) - ((minX + (maxX - minX) / 2) * targetScale);
                    }
                    property real offsetY: {
                        let _ = Monitors.changeTrigger;
                        if (Monitors.monitorsModel.count < 2) return 0;
                        let minY = 999999, maxY = -999999;
                        for (let i = 0; i < Monitors.monitorsModel.count; i++) {
                            let m = Monitors.monitorsModel.get(i);
                            let isP = m.transform === 1 || m.transform === 3;
                            let h = ((isP ? m.resW : m.resH) / m.sysScale) * Monitors.uiScale;
                            minY = Math.min(minY, m.uiY); maxY = Math.max(maxY, m.uiY + h);
                        }
                        return (multiMonContainer.height / 2) - ((minY + (maxY - minY) / 2) * targetScale);
                    }

                    Item {
                        id: monTransformNode
                        x: multiMonContainer.offsetX
                        y: multiMonContainer.offsetY
                        scale: multiMonContainer.targetScale
                        transformOrigin: Item.TopLeft
                        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                        Repeater {
                            model: Monitors.monitorsModel
                            delegate: Item {
                                id: monDelegateItem
                                property bool isActive: Monitors.activeEditIndex === index
                                property bool isPortrait: model.transform === 1 || model.transform === 3
                                property real cardW: (isPortrait ? model.resH : model.resW) / model.sysScale * Monitors.uiScale
                                property real cardH: (isPortrait ? model.resW : model.resH) / model.sysScale * Monitors.uiScale

                                Rectangle {
                                    id: monCard
                                    x: model.uiX
                                    y: model.uiY
                                    width: monDelegateItem.cardW
                                    height: monDelegateItem.cardH
                                    radius: Theme.radius.md
                                    color: isActive ? Theme.color.surface1 : Theme.color.crust
                                    border.color: isActive ? Monitors.selectedResAccent : Theme.color.surface2
                                    border.width: isActive ? 2 : 1
                                    z: isActive ? 5 : 0
                                    Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                    Behavior on border.color { ColorAnimation { duration: 300 } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                    Item {
                                        anchors.centerIn: parent
                                        width: 110; height: 80
                                        property real idealScale: 1.2 / monTransformNode.scale
                                        property real maxPhysicalScale: isPortrait
                                            ? Math.min((parent.width * 0.9) / height, (parent.height * 0.9) / width)
                                            : Math.min((parent.width * 0.9) / width, (parent.height * 0.9) / height)
                                        scale: Math.min(idealScale, maxPhysicalScale)

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            rotation: model.transform * 90
                                            Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                            
                                            BrutalIcon {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.pixelSize: 26
                                                color: isActive ? Monitors.selectedResAccent : Theme.color.text
                                                text: Icons.monitor
                                                Behavior on color { ColorAnimation { duration: 300 } }
                                            }
                                            BrutalText {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.weight: Theme.font.weight.black
                                                font.pixelSize: 10
                                                color: Theme.color.text
                                                text: model.name
                                            }
                                            BrutalText {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.pixelSize: 9
                                                color: Theme.color.subtext0
                                                text: model.resW + "×" + model.resH + "@" + model.rate
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: ghostDrag
                                    x: model.uiX
                                    y: model.uiY
                                    width: monDelegateItem.cardW
                                    height: monDelegateItem.cardH
                                    z: isActive ? 10 : 1

                                    MouseArea {
                                        id: ghostMa
                                        anchors.fill: parent
                                        drag.target: ghostDrag
                                        drag.axis: Drag.XAndYAxis
                                        cursorShape: Qt.SizeAllCursor

                                        onPressed: {
                                            Monitors.activeEditIndex = index;
                                            ghostDrag.x = model.uiX;
                                            ghostDrag.y = model.uiY;
                                        }

                                        onPositionChanged: {
                                            if (!drag.active || Monitors.monitorsModel.count < 2) return;

                                            let mW = monDelegateItem.cardW;
                                            let mH = monDelegateItem.cardH;
                                            let padding = 40;

                                            let boundMinX = 999999, boundMinY = 999999;
                                            let boundMaxX = -999999, boundMaxY = -999999;
                                            for (let j = 0; j < Monitors.monitorsModel.count; j++) {
                                                if (j === index) continue;
                                                let sModel = Monitors.monitorsModel.get(j);
                                                let sIsP = sModel.transform === 1 || sModel.transform === 3;
                                                let sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * Monitors.uiScale;
                                                let sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * Monitors.uiScale;
                                                boundMinX = Math.min(boundMinX, sModel.uiX - mW - padding);
                                                boundMinY = Math.min(boundMinY, sModel.uiY - mH - padding);
                                                boundMaxX = Math.max(boundMaxX, sModel.uiX + sW + padding);
                                                boundMaxY = Math.max(boundMaxY, sModel.uiY + sH + padding);
                                            }
                                            ghostDrag.x = Math.max(boundMinX, Math.min(ghostDrag.x, boundMaxX));
                                            ghostDrag.y = Math.max(boundMinY, Math.min(ghostDrag.y, boundMaxY));

                                            let bestX = ghostDrag.x, bestY = ghostDrag.y, bestDist = 999999;
                                            for (let j = 0; j < Monitors.monitorsModel.count; j++) {
                                                if (j === index) continue;
                                                let sModel = Monitors.monitorsModel.get(j);
                                                let sIsP = sModel.transform === 1 || sModel.transform === 3;
                                                let sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * Monitors.uiScale;
                                                let sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * Monitors.uiScale;
                                                let snapped = Monitors.getPerimeterSnap(
                                                    ghostDrag.x, ghostDrag.y,
                                                    sModel.uiX, sModel.uiY, sW, sH, mW, mH, 20
                                                );
                                                let dist = Math.hypot(ghostDrag.x - snapped.x, ghostDrag.y - snapped.y);
                                                if (dist < bestDist) { bestDist = dist; bestX = snapped.x; bestY = snapped.y; }
                                            }

                                            if (!Monitors.isOverlappingAny(bestX, bestY, mW, mH, index)) {
                                                Monitors.monitorsModel.setProperty(index, "uiX", bestX);
                                                Monitors.monitorsModel.setProperty(index, "uiY", bestY);
                                            }
                                        }

                                        onReleased: {
                                            ghostDrag.x = model.uiX;
                                            ghostDrag.y = model.uiY;
                                            Monitors.changeTrigger++;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                } // End Item wrapper

                // Selected Monitor Info & Controls
                BrutalCard {
                    Layout.fillWidth: true
                    visible: Monitors.monitorsModel.count > 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.space.xl

                        // Left: Rotation Dial
                        Rectangle {
                            id: monDial
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 120
                            Layout.alignment: Qt.AlignVCenter
                            radius: width / 2
                            color: Theme.color.surface0
                            border.color: Theme.color.surface1
                            border.width: 2

                            Repeater {
                                model: 12
                                Item {
                                    anchors.fill: parent
                                    rotation: index * 30
                                    Rectangle {
                                        width: index % 3 === 0 ? 3 : 2
                                        height: index % 3 === 0 ? 8 : 4
                                        radius: width / 2
                                        color: index % 3 === 0 ? Theme.color.subtext0 : Theme.color.surface2
                                        anchors.top: parent.top
                                        anchors.topMargin: 6
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                property int tf: {
                                    let _ = Monitors.changeTrigger;
                                    return Monitors.monitorsModel.count > 0 ? Monitors.monitorsModel.get(Monitors.activeEditIndex).transform : 0;
                                }
                                rotation: tf * 90
                                Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                                Rectangle {
                                    width: 4; height: parent.height / 2 - 22
                                    radius: 2; color: Monitors.selectedResAccent
                                    anchors.bottom: parent.verticalCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                Rectangle {
                                    width: 18; height: 18; radius: 9
                                    color: Theme.color.base
                                    border.color: Monitors.selectedResAccent; border.width: 4
                                    anchors.centerIn: parent
                                    Behavior on border.color { ColorAnimation { duration: 300 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => {
                                    if (Monitors.monitorsModel.count === 0) return;
                                    let cx = width / 2; let cy = height / 2;
                                    let dx = mouse.x - cx; let dy = mouse.y - cy;
                                    if (Math.hypot(dx, dy) < 18) return;
                                    let tf = Monitors.monitorsModel.get(Monitors.activeEditIndex).transform;
                                    let angle = tf * Math.PI / 2;
                                    let rdx = dx * Math.cos(-angle) - dy * Math.sin(-angle);
                                    let rdy = dx * Math.sin(-angle) + dy * Math.cos(-angle);
                                    let rawSnap = Math.abs(rdx) > Math.abs(rdy) ? (rdx > 0 ? 1 : 3) : (rdy > 0 ? 2 : 0);
                                    let snap = (rawSnap + tf) % 4;
                                    Monitors.monitorsModel.setProperty(Monitors.activeEditIndex, "transform", snap);
                                    Monitors.changeTrigger++;
                                    Monitors.delayedLayoutUpdate.restart();
                                }
                            }
                        }

                        // Right: Primary / Workspace settings
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Theme.space.md
                            
                            BrutalText {
                                text: {
                                    let _ = Monitors.changeTrigger;
                                    return Monitors.monitorsModel.count > 0 ? Monitors.monitorsModel.get(Monitors.activeEditIndex).name + " Configuration" : "";
                                }
                                font.pixelSize: Theme.font.size.lg
                                font.weight: Theme.font.weight.bold
                                color: Theme.color.text
                            }

                            RowLayout {
                                spacing: Theme.space.md
                                BrutalButton {
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: 150
                                    
                                    property bool isPrimarySelected: {
                                        let _ = Monitors.changeTrigger;
                                        return Monitors.monitorsModel.count > 0 && Monitors.monitorsModel.get(Monitors.activeEditIndex).isPrimary;
                                    }
                                    
                                    baseColor: isPrimarySelected ? Theme.color.yellow : Theme.color.surface1
                                    hoverColor: isPrimarySelected ? Theme.color.yellow : Theme.color.surface2
                                    shadowed: !isPrimarySelected
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.space.sm
                                        BrutalIcon { 
                                            text: Icons.star; 
                                            color: parent.parent.isPrimarySelected ? Theme.color.crust : Theme.color.text 
                                        }
                                        BrutalText { 
                                            text: parent.parent.isPrimarySelected ? "Primary" : "Set Primary"; 
                                            font.weight: Theme.font.weight.bold; 
                                            color: parent.parent.isPrimarySelected ? Theme.color.crust : Theme.color.text 
                                        }
                                    }

                                    onClicked: {
                                        if (Monitors.monitorsModel.count === 0) return;
                                        for(let i=0; i<Monitors.monitorsModel.count; i++) {
                                            Monitors.monitorsModel.setProperty(i, "isPrimary", i === Monitors.activeEditIndex);
                                        }
                                        Monitors.changeTrigger++;
                                    }
                                }
                            }

                            // Resolution and Refresh Rate
                            Item {
                                id: resConfigItem
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                property var currentMonitor: {
                                    let _ = Monitors.changeTrigger;
                                    return Monitors.monitorsModel.count > 0 ? Monitors.monitorsModel.get(Monitors.activeEditIndex) : null;
                                }
                                property var allModes: currentMonitor ? JSON.parse(currentMonitor.availableModes || "[]") : []
                                property var availableResolutions: {
                                    let res = [];
                                    for(let i=0; i<allModes.length; i++) {
                                        let r = allModes[i].split("@")[0];
                                        if (res.indexOf(r) === -1) res.push(r);
                                    }
                                    return res;
                                }
                                property string currentRes: currentMonitor ? (currentMonitor.resW + "x" + currentMonitor.resH) : ""
                                property var availableRates: {
                                    let rates = [];
                                    for(let i=0; i<allModes.length; i++) {
                                        let parts = allModes[i].split("@");
                                        if (parts[0] === currentRes) {
                                            let rate = Math.round(parseFloat(parts[1])).toString();
                                            if (rates.indexOf(rate) === -1) rates.push(rate);
                                        }
                                    }
                                    return rates;
                                }
                                property string currentRate: currentMonitor ? currentMonitor.rate : ""

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: Theme.space.md
                                    BrutalText { text: "Res:"; font.pixelSize: Theme.font.size.md; color: Theme.color.subtext0 }
                                    ComboBox {
                                        id: resCombo
                                        Layout.preferredWidth: 135
                                        Layout.preferredHeight: 36
                                        model: resConfigItem.availableResolutions
                                        currentIndex: Math.max(0, resConfigItem.availableResolutions.indexOf(resConfigItem.currentRes))
                                        background: Rectangle { color: Theme.color.surface0; border.color: Theme.color.surface2; border.width: 1; radius: Theme.radius.sm }
                                        contentItem: Text { text: resCombo.currentText; color: Theme.color.text; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter; font.family: "JetBrains Mono"; font.pixelSize: 13 }
                                        onActivated: {
                                            if (resConfigItem.currentMonitor) {
                                                let parts = currentText.split("x");
                                                Monitors.monitorsModel.setProperty(Monitors.activeEditIndex, "resW", parseInt(parts[0]));
                                                Monitors.monitorsModel.setProperty(Monitors.activeEditIndex, "resH", parseInt(parts[1]));
                                                Monitors.changeTrigger++;
                                                Monitors.delayedLayoutUpdate.restart();
                                            }
                                        }
                                    }
                                    BrutalText { text: "Hz:"; font.pixelSize: Theme.font.size.md; color: Theme.color.subtext0 }
                                    ComboBox {
                                        id: rateCombo
                                        Layout.preferredWidth: 70
                                        Layout.preferredHeight: 36
                                        model: resConfigItem.availableRates
                                        currentIndex: Math.max(0, resConfigItem.availableRates.indexOf(resConfigItem.currentRate))
                                        background: Rectangle { color: Theme.color.surface0; border.color: Theme.color.surface2; border.width: 1; radius: Theme.radius.sm }
                                        contentItem: Text { text: rateCombo.currentText; color: Theme.color.text; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter; font.family: "JetBrains Mono"; font.pixelSize: 13 }
                                        onActivated: {
                                            if (resConfigItem.currentMonitor) {
                                                Monitors.monitorsModel.setProperty(Monitors.activeEditIndex, "rate", currentText);
                                                Monitors.changeTrigger++;
                                                Monitors.delayedLayoutUpdate.restart();
                                            }
                                        }
                                    }
                                }
                            }

                            // Workspaces config
                            RowLayout {
                                spacing: Theme.space.md
                                BrutalText {
                                    text: "Workspaces:"
                                    font.pixelSize: Theme.font.size.md
                                    color: Theme.color.subtext0
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 180
                                    Layout.preferredHeight: 36
                                    color: Theme.color.surface0
                                    border.color: wsInput.activeFocus ? Monitors.selectedResAccent : Theme.color.surface2
                                    border.width: 1
                                    radius: Theme.radius.sm
                                    
                                    TextInput {
                                        id: wsInput
                                        anchors.fill: parent
                                        anchors.margins: Theme.space.sm
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: Theme.font.size.md
                                        color: Theme.color.text
                                        clip: true
                                        selectByMouse: true
                                        
                                        property string modelText: {
                                            let _ = Monitors.changeTrigger;
                                            return Monitors.monitorsModel.count > 0 ? Monitors.monitorsModel.get(Monitors.activeEditIndex).workspaces : "";
                                        }
                                        
                                        onModelTextChanged: {
                                            if (text !== modelText) text = modelText;
                                        }
                                        
                                        onTextChanged: {
                                            if (activeFocus && Monitors.monitorsModel.count > 0) {
                                                Monitors.monitorsModel.setProperty(Monitors.activeEditIndex, "workspaces", text);
                                            }
                                        }
                                        
                                        BrutalText {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "e.g. 1-5, 9"
                                            color: Qt.alpha(Theme.color.subtext0, 0.45)
                                            visible: !parent.text && !parent.activeFocus
                                        }
                                    }
                                }
                            }
                            
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }
}
