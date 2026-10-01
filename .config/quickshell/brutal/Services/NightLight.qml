pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

/**
 * Colour temperature, via hyprsunset's hyprctl interface.
 *
 * hyprsunset is started from hyprland/execs.lua when it is installed; this
 * service only talks to it. `enabled` is the shell's own state rather than a
 * read-back, because "identity" and "6000K" are indistinguishable over IPC.
 */
Singleton {
    id: root

    property bool enabled: false

    readonly property int temperature: Settings.data.nightLight.temperature
    readonly property bool available: probe.found

    function apply(): void {
        Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature",
            `${root.temperature}`]);
    }

    function enable(): void {
        if (!root.available) return;
        root.enabled = true;
        root.apply();
    }

    function disable(): void {
        root.enabled = false;
        Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
    }

    function toggle(): void {
        if (root.enabled) root.disable();
        else root.enable();
    }

    // Re-apply when the temperature is edited in settings.json while on.
    onTemperatureChanged: {
        if (root.enabled) root.apply();
    }

    // ── Scheduler ──────────────────────────────────────────────────────────
    readonly property bool scheduleSunset: Settings.data.nightLight.scheduleSunset
    readonly property bool scheduleCustom: Settings.data.nightLight.scheduleCustom
    readonly property int customOn: Settings.data.nightLight.customOn
    readonly property int customOff: Settings.data.nightLight.customOff

    readonly property bool isDay: Weather.isDay
    readonly property int currentHour: Time.now.getHours()

    function evaluateSchedule(): void {
        if (root.scheduleSunset) {
            if (root.isDay) root.disable();
            else root.enable();
        } else if (root.scheduleCustom) {
            let active = false;
            if (root.customOn < root.customOff) {
                active = (root.currentHour >= root.customOn && root.currentHour < root.customOff);
            } else {
                active = (root.currentHour >= root.customOn || root.currentHour < root.customOff);
            }
            if (active) root.enable();
            else root.disable();
        }
    }

    onScheduleSunsetChanged: evaluateSchedule()
    onScheduleCustomChanged: evaluateSchedule()
    onCustomOnChanged: evaluateSchedule()
    onCustomOffChanged: evaluateSchedule()
    onIsDayChanged: evaluateSchedule()
    onCurrentHourChanged: evaluateSchedule()

    Process {
        id: probe

        property bool found: false

        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null"]
        onExited: code => probe.found = code === 0
    }
}
