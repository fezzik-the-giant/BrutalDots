pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import qs.Config

/**
 * StatusNotifierItem tray.
 *
 * Passive items are kept by default: the specification says they are
 * uninteresting, but plenty of applications mislabel a perfectly useful icon,
 * and a tray that silently swallows icons is worse than a busy one. Turn
 * `bar.trayHidePassive` on to follow the spec instead.
 */
Singleton {
    id: root

    readonly property var all: SystemTray.items?.values ?? []

    readonly property var items: root.all.filter(item => {
        const ignored = Settings.data.bar.trayIgnored ?? [];
        if (ignored.indexOf(item.id) !== -1) return false;
        if (Settings.data.bar.trayHidePassive && item.status === Status.Passive) return false;
        return true;
    })

    readonly property int count: root.items.length

    /// Ids the passive filter is currently dropping. The settings list keeps a
    /// row for every item, so it has to be able to say which of them the bar
    /// is already hiding — otherwise "Visible applications" contradicts the
    /// passive toggle sitting directly above it.
    readonly property var passiveHidden: Settings.data.bar.trayHidePassive
        ? root.all.filter(item => item.status === Status.Passive).map(item => item.id)
        : []
}
