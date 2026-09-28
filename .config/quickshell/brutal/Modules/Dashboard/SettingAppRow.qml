import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services

RowLayout {
    id: root
    
    property string label: ""
    property string description: ""
    property string category: ""
    property string fallbackCategory: ""
    property var extraMatch: null
    property string value: ""
    
    signal changed(string exec)
    
    spacing: Theme.space.md

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -1

        BrutalText {
            text: root.label
            font.pixelSize: Theme.font.size.lg
            font.weight: Theme.font.weight.bold
        }

        BrutalText {
            visible: root.description !== ""
            text: root.description
            dim: true
            font.pixelSize: Theme.font.size.sm
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    BrutalComboBox {
        Layout.preferredWidth: 200
        Layout.alignment: Qt.AlignVCenter
        
        model: {
            let candidates = Apps.all.filter(e => {
                if (root.extraMatch && root.extraMatch(e.name.toLowerCase())) return true;
                if (!e.categories) return false;
                let cats = e.categories.join(";");
                return cats.includes(root.category) || (root.fallbackCategory && cats.includes(root.fallbackCategory));
            });
            // Map to an array of objects for the combobox
            let mapped = candidates.map(e => ({
                text: e.name,
                exec: e.execString.split(" ")[0].split("/").pop()
            }));
            
            // Remove duplicates
            let seen = new Set();
            return mapped.filter(item => {
                let duplicate = seen.has(item.exec);
                seen.add(item.exec);
                return !duplicate;
            }).sort((a, b) => a.text.localeCompare(b.text));
        }
        
        textRole: "text"
        valueRole: "exec"
        
        // Find current index based on value
        currentIndex: {
            if (!model) return -1;
            for (let i = 0; i < model.length; i++) {
                if (model[i].exec === root.value) return i;
            }
            return -1;
        }
        
        onActivated: index => {
            if (index >= 0 && index < model.length) {
                root.changed(model[index].exec);
            }
        }
    }
}
