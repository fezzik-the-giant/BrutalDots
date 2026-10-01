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

    // ── Applying ───────────────────────────────────────────────────────────
    /// One hyprctl, no throttle. For discrete actions only.
    function applyNow(): void {
        if (!root.available) return;
        root.applyPending = false;
        Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature",
            `${root.temperature}`]);
    }

    property bool applyPending: false

    /// Throttled, for the temperature slider: SettingRow forwards BrutalSlider's
    /// `moved`, which fires on every pointer move, so an unthrottled path forks
    /// a process per mouse event. Same shape as Appearance.apply() — see
    /// AGENTS.md, "Live-preview cost".
    function apply(): void {
        if (!root.available) return;
        // Leading edge, so the first movement of a drag is immediate.
        if (applyThrottle.running) {
            root.applyPending = true;
            return;
        }
        root.applyNow();
        applyThrottle.start();
    }

    // ...and then at most one call per interval while it continues. The
    // trailing flush guarantees the value you release on is the one that lands.
    Timer {
        id: applyThrottle
        interval: 50
        onTriggered: {
            if (!root.applyPending) return;
            root.applyNow();
            applyThrottle.start();
        }
    }

    function enable(): void {
        if (!root.available) return;
        root.enabled = true;
        root.applyNow();
    }

    function disable(): void {
        // Guarded like enable(): without it a schedule left on by someone who
        // has no hyprsunset runs a failing hyprctl at every transition.
        if (!root.available) return;
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

    /// Sun times, not Weather.isDay. `isDay` defaults to true and is only
    /// written on a successful forecast parse, so an offline or rate-limited
    /// shell reads as permanent daylight and the schedule silently never
    /// fires. Empty strings mean "no data", which the UI reports rather than
    /// guessing at.
    readonly property bool sunKnown: Weather.sunrise !== "" && Weather.sunset !== ""

    function minutesOfDay(d: date): int {
        return d.getHours() * 60 + d.getMinutes();
    }

    // Parsed once per forecast rather than once per clock tick.
    readonly property int sunriseMinutes: root.sunKnown
        ? root.minutesOfDay(new Date(Weather.sunrise)) : -1
    readonly property int sunsetMinutes: root.sunKnown
        ? root.minutesOfDay(new Date(Weather.sunset)) : -1

    /// Compared as time-of-day rather than as instants, so a forecast that has
    /// gone stale overnight still answers correctly. Assumes sunrise precedes
    /// sunset, which stops being true inside the polar circles.
    readonly property bool isNight: {
        if (!root.sunKnown) return false;
        const now = root.minutesOfDay(Time.now);
        return now < root.sunriseMinutes || now >= root.sunsetMinutes;
    }

    readonly property int currentHour: Time.now.getHours()

    /// What the active schedule says the state should be: 1 on, 0 off, -1 when
    /// no schedule is set or the one that is cannot answer.
    readonly property int scheduleVerdict: {
        if (root.scheduleSunset) {
            if (!root.sunKnown) return -1;
            return root.isNight ? 1 : 0;
        }
        if (root.scheduleCustom) {
            // A zero-length window reads as inactive. Left to the general case
            // it takes the wrapping branch and matches every hour of the day.
            if (root.customOn === root.customOff) return 0;
            const h = root.currentHour;
            const active = root.customOn < root.customOff
                ? (h >= root.customOn && h < root.customOff)
                : (h >= root.customOn || h < root.customOff);
            return active ? 1 : 0;
        }
        return -1;
    }

    function applyVerdict(): void {
        if (root.scheduleVerdict === 1) root.enable();
        else if (root.scheduleVerdict === 0) root.disable();
    }

    /// Acted on only when it changes. The clock ticks every second, so running
    /// the schedule on every tick would undo a manual toggle within the hour;
    /// keying off the transition lets a manual change stand until the next one.
    onScheduleVerdictChanged: root.applyVerdict()

    /// The probe is asynchronous and singletons are lazy, so a schedule loaded
    /// from settings.json is usually evaluated before `available` is known and
    /// enable() returns early. Without this the screen stays cold until the
    /// next transition.
    onAvailableChanged: {
        if (root.available) root.applyVerdict();
    }

    onScheduleSunsetChanged: root.schedulesChanged()
    onScheduleCustomChanged: root.schedulesChanged()

    /// Turning the last schedule off hands control back — and leaving the
    /// screen warm with no schedule left that could ever cool it is not
    /// handing it back.
    function schedulesChanged(): void {
        if (!root.scheduleSunset && !root.scheduleCustom && root.enabled)
            root.disable();
    }

    Process {
        id: probe

        property bool found: false

        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null"]
        onExited: code => probe.found = code === 0
    }
}
