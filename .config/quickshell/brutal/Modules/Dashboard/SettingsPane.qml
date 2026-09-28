import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Components
import qs.Services

/**
 * The dashboard's Settings tab: idle behaviour, the night light, Hyprland's
 * window appearance, the system tray and the lock screen.
 *
 * Most of it writes to settings.json through its JsonAdapter. Appearance is
 * the exception: it writes into a block in custom/general.lua and applies live
 * through `hyprctl eval` — see Services/Appearance.qml for why those are not
 * the same mechanism. Either way there is no save button: everything applies
 * at once.
 */
ColumnLayout {
    id: root

    readonly property var idle: Settings.data.idle

    /// The ladder runs dim → lock → screen off → suspend. Set out of order and
    /// the later step fires first, which looks like the earlier one is broken.
    readonly property bool outOfOrder: {
        const steps = [root.idle.dimAfter, root.idle.lockAfter,
            root.idle.screenOffAfter, root.idle.suspendAfter].filter(v => v > 0);
        for (let i = 1; i < steps.length; i++) {
            if (steps[i] < steps[i - 1]) return true;
        }
        return false;
    }

    readonly property int appearanceCount:
        Appearance.settings.filter(s => Appearance.isOverridden(s.id)).length

    spacing: Theme.space.lg

    // The pane is taller than the panel now, so it scrolls rather than being
    // clipped at whatever card happens to fall off the bottom.
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

                // Room for the card shadows, which fall outside their bounds.
                width: scroll.width - Theme.shadow.md
                spacing: Theme.space.lg

                // ── Palette ────────────────────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    title: "Palette"
                    icon: Icons.theme
                    padding: Theme.space.xl

                    SettingRow {
                        Layout.fillWidth: true
                        label: "Dark mode"
                        description: "Inverts the whole shell at once — ink becomes "
                            + "cream, and the pastels become the deep tones that read "
                            + "under it. Hyprland's border and shadow follow"
                        type: "bool"
                        tint: Theme.color.lavender
                        checked: Theme.dark
                        onToggled: on => Theme.setDark(on)
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    SettingRow {
                        Layout.fillWidth: true
                        enabled: NightLight.available
                        opacity: NightLight.available ? 1 : 0.5
                        label: "Night light"
                        description: NightLight.available
                            ? "Warms the screen colours to reduce eye strain"
                            : "Requires hyprsunset, which is not installed"
                        type: "bool"
                        tint: Theme.color.peach
                        checked: NightLight.enabled
                        onToggled: on => on ? NightLight.enable() : NightLight.disable()
                    }

                    BrutalDivider {
                        Layout.fillWidth: true
                        visible: NightLight.inUse
                    }

                    SettingRow {
                        Layout.fillWidth: true
                        visible: NightLight.inUse
                        enabled: NightLight.available
                        opacity: NightLight.available ? 1 : 0.5
                        label: "Temperature"
                        description: "How warm the display gets (lower is warmer)"
                        type: "int"
                        tint: Theme.color.peach
                        minimum: 1000
                        maximum: 10000
                        value: Settings.data.nightLight.temperature
                        format: v => v + "K"
                        onMoved: v => Settings.data.nightLight.temperature = v
                    }

                    BrutalDivider {
                        Layout.fillWidth: true
                        visible: NightLight.inUse
                    }

                    SettingRow {
                        Layout.fillWidth: true
                        visible: NightLight.inUse
                        enabled: NightLight.available
                        opacity: NightLight.available ? 1 : 0.5
                        label: "Sunset to sunrise"
                        description: !NightLight.available ? "Requires hyprsunset, which is not installed"
                            : NightLight.sunKnown
                                ? "Automatically turn on when the sun goes down"
                                : "Waiting on sunrise and sunset times from the forecast"
                        type: "bool"
                        tint: Theme.color.blue
                        checked: Settings.data.nightLight.scheduleSunset
                        onToggled: on => {
                            Settings.data.nightLight.scheduleSunset = on;
                            if (on) Settings.data.nightLight.scheduleCustom = false;
                        }
                    }

                    SettingRow {
                        Layout.fillWidth: true
                        visible: NightLight.inUse
                        enabled: NightLight.available
                        opacity: NightLight.available ? 1 : 0.5
                        label: "Custom schedule"
                        description: "Automatically turn on between specific hours"
                        type: "bool"
                        tint: Theme.color.blue
                        checked: Settings.data.nightLight.scheduleCustom
                        onToggled: on => {
                            Settings.data.nightLight.scheduleCustom = on;
                            if (on) Settings.data.nightLight.scheduleSunset = false;
                        }
                    }

                    SettingRow {
                        Layout.fillWidth: true
                        visible: Settings.data.nightLight.scheduleCustom
                        enabled: NightLight.available
                        opacity: NightLight.available ? 1 : 0.5
                        label: "Turn on at"
                        description: "Hour of the day"
                        type: "int"
                        tint: Theme.color.lavender
                        minimum: 0
                        maximum: 23
                        value: Settings.data.nightLight.customOn
                        format: v => (v < 10 ? "0" + v : v) + ":00"
                        onMoved: v => Settings.data.nightLight.customOn = v
                    }

                    SettingRow {
                        Layout.fillWidth: true
                        visible: Settings.data.nightLight.scheduleCustom
                        enabled: NightLight.available
                        opacity: NightLight.available ? 1 : 0.5
                        label: "Turn off at"
                        description: "Hour of the day"
                        type: "int"
                        tint: Theme.color.lavender
                        minimum: 0
                        maximum: 23
                        value: Settings.data.nightLight.customOff
                        format: v => (v < 10 ? "0" + v : v) + ":00"
                        onMoved: v => Settings.data.nightLight.customOff = v
                    }
                }

                // ── Idle ladder ────────────────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    title: "Idle"
                    icon: Icons.uptime
                    padding: Theme.space.xl

                    TimeoutRow {
                        Layout.fillWidth: true
                        label: "Dim the screen"
                        description: "Fades an overlay over everything, at the opacity below"
                        icon: Icons.dim
                        tint: Theme.color.peach
                        value: root.idle.dimAfter
                        onChanged: v => root.idle.dimAfter = v
                    }

                    TimeoutRow {
                        Layout.fillWidth: true
                        label: "Lock the session"
                        description: "The same lock as SUPER+ALT+L and loginctl lock-session"
                        icon: Icons.lock
                        tint: Theme.color.salmon
                        value: root.idle.lockAfter
                        onChanged: v => root.idle.lockAfter = v
                    }

                    TimeoutRow {
                        Layout.fillWidth: true
                        label: "Turn the screens off"
                        description: "DPMS off; any input turns them back on"
                        icon: Icons.monitorOff
                        tint: Theme.color.lavender
                        value: root.idle.screenOffAfter
                        onChanged: v => root.idle.screenOffAfter = v
                    }

                    TimeoutRow {
                        Layout.fillWidth: true
                        label: "Suspend"
                        description: "systemctl suspend — off by default"
                        icon: Icons.sleep
                        tint: Theme.color.blue
                        value: root.idle.suspendAfter
                        onChanged: v => root.idle.suspendAfter = v
                    }

                    // Only shown when it is actually true, so it reads as a
                    // problem with what you just set rather than as chrome.
                    RowLayout {
                        visible: root.outOfOrder
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.space.xs
                        spacing: Theme.space.sm

                        BrutalIcon {
                            text: Icons.alert
                            color: Theme.mark.red
                            font.pixelSize: Theme.font.icon.sm
                        }

                        BrutalText {
                            Layout.fillWidth: true
                            text: "These run out of order — a later step will fire first."
                            font.pixelSize: Theme.font.size.sm
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // ── Idle behaviour ─────────────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    title: "Behaviour"
                    icon: Icons.settings
                    padding: Theme.space.xl

                    SettingRow {
                        Layout.fillWidth: true
                        label: "Dim opacity"
                        description: "How dark the dim step goes"
                        type: "real"
                        minimum: 0
                        maximum: 1
                        tint: Theme.color.peach
                        value: root.idle.dimOpacity
                        format: v => `${Math.round(v * 100)}%`
                        onMoved: v => root.idle.dimOpacity = Math.round(v * 20) / 20
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    SettingRow {
                        Layout.fillWidth: true
                        label: "Stay awake in fullscreen"
                        description: "Holds every step off while a fullscreen window is "
                            + "focused — a gamepad never reaches the idle timer"
                        type: "bool"
                        tint: Theme.color.green
                        checked: root.idle.inhibitFullscreen
                        onToggled: on => root.idle.inhibitFullscreen = on
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    SettingRow {
                        Layout.fillWidth: true
                        label: "Keep awake now"
                        description: "The same override as SUPER+SHIFT+I. Not saved — it "
                            + "lasts until you turn it off or log out"
                        type: "bool"
                        tint: Theme.color.mint
                        checked: Idle.inhibited
                        onToggled: on => Idle.inhibited = on
                    }
                }

                // ── Window appearance ──────────────────────────────────────
                Repeater {
                    model: Appearance.groups

                    delegate: BrutalCard {
                        id: group

                        required property string modelData

                        Layout.fillWidth: true
                        title: group.modelData
                        icon: Icons.monitor
                        padding: Theme.space.xl

                        Repeater {
                            model: Appearance.settings.filter(
                                s => s.group === group.modelData)

                            delegate: SettingRow {
                                id: row

                                required property var modelData

                                Layout.fillWidth: true
                                label: row.modelData.label
                                description: row.modelData.description
                                type: row.modelData.type
                                minimum: row.modelData.min ?? 0
                                maximum: row.modelData.max ?? 1
                                tint: Theme.color.blue
                                resettable: true
                                overridden: Appearance.isOverridden(row.modelData.id)
                                value: Appearance.value(row.modelData.id)
                                checked: Appearance.value(row.modelData.id) === true

                                format: v => row.modelData.type === "int"
                                    ? String(Math.round(v))
                                    : `${Math.round(v * 100)}%`

                                onMoved: v => Appearance.set(row.modelData.id, v)
                                onToggled: on => Appearance.set(row.modelData.id, on)
                                onRestore: Appearance.reset(row.modelData.id)
                            }
                        }
                    }
                }

                // ── Restoring appearance ───────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    padding: Theme.space.xl

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space.md

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -1

                            BrutalText {
                                text: "Restore window appearance"
                                font.pixelSize: Theme.font.size.lg
                                font.weight: Theme.font.weight.bold
                            }

                            BrutalText {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                dim: true
                                font.pixelSize: Theme.font.size.sm
                                text: root.appearanceCount > 0
                                    ? `${root.appearanceCount} setting`
                                        + (root.appearanceCount === 1 ? "" : "s")
                                        + " changed here. Clearing them hands every one back "
                                        + "to hyprland/general.lua and your own custom/general.lua."
                                    : "Nothing changed here — every window setting is "
                                        + "coming from your Hyprland config."
                            }
                        }

                        BrutalButton {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 130
                            implicitHeight: 38
                            radius: Theme.radius.sm
                            enabled: Appearance.ready && root.appearanceCount > 0
                            baseColor: Theme.color.base
                            hoverColor: Theme.color.peach
                            onClicked: Appearance.resetAll()

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space.sm

                                BrutalIcon {
                                    text: Icons.restart
                                    font.pixelSize: Theme.font.icon.sm
                                }

                                BrutalText {
                                    text: root.appearanceCount > 0
                                        ? `Reset ${root.appearanceCount}` : "No changes"
                                    font.pixelSize: Theme.font.size.md
                                    font.weight: Theme.font.weight.bold
                                }
                            }
                        }
                    }
                }

                // ── System Tray ────────────────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    title: "System Tray"
                    icon: Icons.tray
                    padding: Theme.space.xl

                    SettingRow {
                        Layout.fillWidth: true
                        label: "Hide passive items"
                        description: "Follows the spec to hide uninteresting icons, though many apps mislabel useful ones"
                        type: "bool"
                        tint: Theme.color.peach
                        checked: Settings.data.bar.trayHidePassive
                        onToggled: on => Settings.data.bar.trayHidePassive = on
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    ColumnLayout {
                        id: trayList

                        Layout.fillWidth: true
                        spacing: Theme.space.md

                        /// A snapshot, deliberately not a binding over
                        /// trayIgnored. The rows write that list, so a model
                        /// derived from it is rebuilt from inside the handler
                        /// of the row just clicked — and re-ticking an app
                        /// that has since quit would delete its own row
                        /// mid-click, because the id leaves trayIgnored
                        /// without being in Tray.all. Refreshed when the tray
                        /// changes or the pane is opened, never while a row
                        /// is being toggled.
                        property var rows: []

                        function refreshRows(): void {
                            const byId = ({});
                            // Hidden apps that are not running have no item to
                            // read a title from; the id is all we have.
                            (Settings.data.bar.trayIgnored ?? []).forEach(id => {
                                byId[id] = ({ id: id, title: "" });
                            });
                            Tray.all.forEach(item => {
                                byId[item.id] = ({ id: item.id, title: item.title ?? "" });
                            });
                            // Sorted by what the row actually shows, not by
                            // the id, or a list labelled with titles comes out
                            // in an order with no visible logic.
                            trayList.rows = Object.keys(byId).map(k => byId[k]).sort((a, b) =>
                                (a.title || a.id).toLowerCase().localeCompare((b.title || b.id).toLowerCase()));
                        }

                        Component.onCompleted: trayList.refreshRows()
                        onVisibleChanged: if (trayList.visible) trayList.refreshRows()

                        Connections {
                            target: Tray
                            function onAllChanged(): void { trayList.refreshRows(); }
                        }

                        BrutalText {
                            text: "Visible applications"
                            font.pixelSize: Theme.font.size.lg
                            font.weight: Theme.font.weight.bold
                        }

                        BrutalText {
                            text: trayList.rows.length > 0
                                ? "Uncheck an app to hide it from the bar. Only shows active apps and ones you've already hidden."
                                : "No applications are using the system tray."
                            dim: true
                            font.pixelSize: Theme.font.size.sm
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: trayList.rows

                            delegate: SettingRow {
                                id: trayRow

                                required property var modelData
                                readonly property string trayId: trayRow.modelData.id
                                readonly property bool passiveHidden:
                                    Tray.passiveHidden.indexOf(trayRow.trayId) !== -1

                                Layout.fillWidth: true
                                // The id stays the stored key, because that is
                                // what Tray.qml filters on, but the spec only
                                // promises it is unique — title is the field
                                // defined as human-readable. Same fallback
                                // order as TrayMenu.
                                label: trayRow.modelData.title || trayRow.trayId
                                description: trayRow.passiveHidden
                                    ? "Hidden by \"Hide passive items\""
                                    : (trayRow.modelData.title && trayRow.modelData.title !== trayRow.trayId
                                        ? trayRow.trayId
                                        : "")
                                type: "bool"
                                tint: Theme.color.blue
                                checked: (Settings.data.bar.trayIgnored ?? []).indexOf(trayRow.trayId) === -1
                                onToggled: on => {
                                    let current = Array.from(Settings.data.bar.trayIgnored ?? []);
                                    if (on)
                                        current = current.filter(id => id !== trayRow.trayId);
                                    else if (current.indexOf(trayRow.trayId) === -1)
                                        current.push(trayRow.trayId);
                                    Settings.data.bar.trayIgnored = current;
                                }
                            }
                        }
                    }
                }

                // ── Default Applications ───────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    title: "Default Apps"
                    icon: Icons.appGrid
                    padding: Theme.space.xl

                    SettingAppRow {
                        Layout.fillWidth: true
                        label: "Terminal"
                        category: "TerminalEmulator"
                        value: Settings.data.apps.terminal
                        onChanged: exec => Settings.data.apps.terminal = exec
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    SettingAppRow {
                        Layout.fillWidth: true
                        label: "Browser"
                        category: "WebBrowser"
                        value: Settings.data.apps.browser
                        onChanged: exec => Settings.data.apps.browser = exec
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    SettingAppRow {
                        Layout.fillWidth: true
                        label: "File Manager"
                        category: "FileManager"
                        value: Settings.data.apps.files
                        onChanged: exec => Settings.data.apps.files = exec
                    }

                    BrutalDivider { Layout.fillWidth: true }
                    
                    SettingAppRow {
                        Layout.fillWidth: true
                        label: "Music Player"
                        category: "Audio"
                        fallbackCategory: "AudioVideo"
                        value: Settings.data.apps.music
                        onChanged: exec => Settings.data.apps.music = exec
                    }

                    BrutalDivider { Layout.fillWidth: true }
                    
                    SettingAppRow {
                        Layout.fillWidth: true
                        label: "Text Editor"
                        category: "TextEditor"
                        fallbackCategory: "Development"
                        value: Settings.data.apps.editor
                        onChanged: exec => Settings.data.apps.editor = exec
                    }

                    BrutalDivider { Layout.fillWidth: true }
                    
                    SettingAppRow {
                        Layout.fillWidth: true
                        label: "Chat / Messaging"
                        category: "InstantMessaging"
                        fallbackCategory: "Chat"
                        extraMatch: name => name.includes("vesktop") || name.includes("discord") || name.includes("teams") || name.includes("slack")
                        value: Settings.data.apps.chat
                        onChanged: exec => Settings.data.apps.chat = exec
                    }
                }

                // ── Quick Links ────────────────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    title: "Quick Links"
                    icon: Icons.browser
                    padding: Theme.space.xl
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space.md

                        // Header Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space.sm

                            BrutalText {
                                Layout.preferredWidth: 100
                                text: "Name"
                                dim: true
                                font.pixelSize: Theme.font.size.sm
                                font.weight: Theme.font.weight.bold
                            }

                            BrutalText {
                                Layout.fillWidth: true
                                text: "URL"
                                dim: true
                                font.pixelSize: Theme.font.size.sm
                                font.weight: Theme.font.weight.bold
                            }

                            BrutalText {
                                Layout.preferredWidth: 80
                                text: "Icon"
                                dim: true
                                font.pixelSize: Theme.font.size.sm
                                font.weight: Theme.font.weight.bold
                            }

                            Item {
                                // Spacer for the delete button column
                                Layout.preferredWidth: 38
                            }
                        }

                        Repeater {
                            model: Settings.data.quickLinks
                            delegate: RowLayout {
                                id: linkRow
                                required property var modelData
                                required property int index
                                
                                Layout.fillWidth: true
                                spacing: Theme.space.sm

                                BrutalTextField {
                                    Layout.preferredWidth: 100
                                    text: linkRow.modelData.name
                                    placeholder: "Name"
                                    onAccepted: val => {
                                        let arr = Array.from(Settings.data.quickLinks);
                                        arr[linkRow.index].name = val;
                                        Settings.data.quickLinks = arr;
                                    }
                                }

                                BrutalTextField {
                                    Layout.fillWidth: true
                                    text: linkRow.modelData.url
                                    placeholder: "https://"
                                    onAccepted: val => {
                                        let arr = Array.from(Settings.data.quickLinks);
                                        arr[linkRow.index].url = val;
                                        Settings.data.quickLinks = arr;
                                    }
                                }

                                BrutalTextField {
                                    Layout.preferredWidth: 80
                                    text: linkRow.modelData.icon
                                    placeholder: "Icon"
                                    onAccepted: val => {
                                        let arr = Array.from(Settings.data.quickLinks);
                                        arr[linkRow.index].icon = val;
                                        Settings.data.quickLinks = arr;
                                    }
                                }

                                BrutalIconButton {
                                    icon: Icons.close
                                    size: 38
                                    onClicked: {
                                        let arr = Array.from(Settings.data.quickLinks);
                                        arr.splice(linkRow.index, 1);
                                        Settings.data.quickLinks = arr;
                                    }
                                }
                            }
                        }

                        BrutalButton {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Theme.space.sm
                            implicitWidth: 120
                            implicitHeight: 34
                            radius: Theme.radius.sm
                            baseColor: Theme.color.mint
                            
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space.sm
                                BrutalIcon { text: Icons.plus; color: Theme.color.ink }
                                BrutalText { text: "Add Link"; color: Theme.color.ink; font.weight: Theme.font.weight.bold }
                            }
                            
                            onClicked: {
                                let arr = Array.from(Settings.data.quickLinks ?? []);
                                arr.push({ name: "New Link", url: "https://", icon: "browser", color: "blue" });
                                Settings.data.quickLinks = arr;
                            }
                        }
                    }
                }

                // ── Lock ───────────────────────────────────────────────────
                BrutalCard {
                    Layout.fillWidth: true
                    title: "Lock"
                    icon: Icons.lock
                    padding: Theme.space.xl

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space.md

                        ColumnLayout {
                            Layout.preferredWidth: 260
                            spacing: -1

                            BrutalText {
                                text: "Message"
                                font.pixelSize: Theme.font.size.lg
                                font.weight: Theme.font.weight.bold
                            }

                            BrutalText {
                                text: "Shown under the password box"
                                dim: true
                                font.pixelSize: Theme.font.size.sm
                            }
                        }

                        BrutalTextField {
                            id: message

                            Layout.fillWidth: true
                            acceptEmpty: true
                            placeholder: "Nothing to see here"
                            text: Settings.data.lock.message

                            // Committed on Return and on losing focus, not per
                            // keystroke: every keystroke would queue a write.
                            onAccepted: t => Settings.data.lock.message = t
                            onActiveFocusChanged: {
                                if (!activeFocus) Settings.data.lock.message = message.text;
                            }
                        }
                    }

                    BrutalDivider { Layout.fillWidth: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space.md

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -1

                            BrutalText {
                                text: "Authentication"
                                font.pixelSize: Theme.font.size.lg
                                font.weight: Theme.font.weight.bold
                            }

                            BrutalText {
                                text: `PAM, against /etc/pam.d/${Settings.data.lock.pamConfig}. `
                                    + "Edit this one in settings.json — a wrong value here "
                                    + "would lock you out of your own session"
                                dim: true
                                font.pixelSize: Theme.font.size.sm
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        BrutalButton {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 108
                            implicitHeight: 38
                            radius: Theme.radius.sm
                            baseColor: Theme.color.salmon
                            hoverColor: Theme.color.coral

                            onClicked: {
                                ShellState.closeAll();
                                ShellState.locked = true;
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.space.sm

                                BrutalIcon {
                                    text: Icons.lock
                                    font.pixelSize: Theme.font.icon.sm
                                }

                                BrutalText {
                                    text: "Lock now"
                                    font.pixelSize: Theme.font.size.md
                                    font.weight: Theme.font.weight.bold
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
