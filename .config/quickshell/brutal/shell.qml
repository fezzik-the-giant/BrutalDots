//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.Config
import qs.Services
import qs.Modules.Bar
import qs.Modules.Wallpaper
import qs.Modules.Media
import qs.Modules.Bluetooth
import qs.Modules.Network
import qs.Modules.Audio
import qs.Modules.Dashboard
import qs.Modules.Launcher
import qs.Modules.Lock
import qs.Modules.Polkit
import qs.Modules.Widgets
import qs.Modules.Notifications
import qs.Modules.Osd
import qs.Modules.Power

/**
 * BrutalDots — a neo-brutalist Hyprland shell built on Quickshell.
 *
 */
ShellRoot {
    id: root

    Backdrop {}
    Bar {}
    Dashboard {}
    Launcher {}
    Picker {}
    MiniPlayer {}
    BluetoothMenu {}
    WifiMenu {}
    AudioMenu {}
    Lock {}
    Dim {}
    PolkitDialog {}
    Widgets {}
    NotificationToasts {}
    NotificationPanel {}
    Osd {}
    PowerMenu {}

    // Hyprland's frame and kitty's palette are both drawn from the shell's ink,
    // so both have to be told when it changes. The trigger lives here rather
    // than inside those two services because a Quickshell singleton is only
    // built the first time something reads it — one whose entire job was to sit
    // and wait for a signal would never be built to hear it.
    //
    // Only the compositor needs the startup push for its own sake: it forgets
    // on every `hyprctl reload`, while kitty's pointer is a file that persists.
    // The greeter is pushed at startup too, for a different reason — installing
    // the login screen while already in dark mode leaves its state file saying
    // light, and without this you would have to toggle twice to correct it.
    //
    // It waits for `Settings.ready`: settings.json loads asynchronously, so at
    // `onCompleted` `Theme.dark` is still the default and the push would send
    // light. See AGENTS.md "Dark mode propagation".
    function pushPalette(): void {
        Appearance.syncPalette();
        Greeter.sync();
        Toolkit.sync();
    }

    Component.onCompleted: if (Settings.ready) pushPalette()

    Connections {
        target: Settings
        function onReadyChanged(): void {
            if (Settings.ready) root.pushPalette();
        }
    }

    Connections {
        target: Theme
        function onDarkChanged(): void {
            Appearance.syncPalette();
            Terminal.sync();
            Greeter.sync();
            Toolkit.sync();
        }
    }

    // ── Control surface ────────────────────────────────────────────────────
    // Usable from a Hyprland bind: `qs -c brutal ipc call shell dashboard`
    IpcHandler {
        target: "shell"

        function dashboard(): void { ShellState.toggleDashboard(); }
        function widgets(): void { ShellState.toggleWidgets(); }
        function notifications(): void { ShellState.toggleNotifications(); }
        function power(): void { ShellState.togglePowerMenu(); }
        function launcher(): void { ShellState.openLauncher("apps"); }
        function clipboard(): void { ShellState.openLauncher("clipboard"); }
        function lock(): void { ShellState.locked = true; }

        /// Expand the now-playing capsule into the mini player.
        function media(): void { ShellState.toggleMedia(); }

        /// Bluetooth devices, with connect / disconnect and a power toggle.
        function bluetooth(): void { ShellState.toggleBluetooth(); }

        /// Audio devices, with output/input switching and levels.
        function audio(): void { ShellState.toggleAudio(); }

        /// Wi-Fi networks, with join / leave and a radio toggle.
        function wifi(): void { ShellState.toggleWifi(); }

        /// Flip the whole shell between the cream palette and the ink one.
        function darkMode(): void { Theme.toggleDark(); }

        /// Set it outright, for anything that must not guess which way a
        /// toggle will land: `qs -c brutal ipc call shell setTheme dark`
        function setTheme(mode: string): void { Theme.setDark(mode === "dark"); }

        /// Switch output device by name, for scripts and keybinds:
        /// `qs -c brutal ipc call shell setSink "G733"`. Matches the first
        /// device whose name contains the text, case-insensitively.
        function setSink(match: string): void { Audio.selectSink(match); }
        function setSource(match: string): void { Audio.selectSource(match); }
        function keepAwake(): void { Idle.toggleInhibit(); }
        function nightLight(): void { NightLight.toggle(); }

        function screenshot(mode: string): void {
            if (mode === "screen") Capture.screen();
            else if (mode === "window") Capture.window();
            else Capture.region();
        }

        function record(mode: string): void { Capture.toggleRecording(mode === "region"); }

        /// Open the picker: `qs -c brutal ipc call shell wallpaper`
        function wallpaper(): void { ShellState.toggleWallpaperPicker(); }

        /// Set one directly, skipping the picker:
        /// `qs -c brutal ipc call shell setWallpaper ~/Pictures/wall.png`
        function setWallpaper(path: string): void { Wallpaper.select(path); }
        function pickColour(): void { Capture.pickColour(); }
        function close(): void { ShellState.closeAll(); }
    }

    // Hyprland global shortcuts, bound with `bind = SUPER, D, global, brutaldots:dashboard`
    GlobalShortcut {
        appid: "brutaldots"
        name: "dashboard"
        description: "Toggle the BrutalDots dashboard"
        onPressed: ShellState.toggleDashboard()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "widgets"
        description: "Toggle the BrutalDots widget layer"
        onPressed: ShellState.toggleWidgets()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "wallpaper"
        description: "Open the BrutalDots wallpaper picker"
        onPressed: ShellState.toggleWallpaperPicker()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "power"
        description: "Toggle the BrutalDots power menu"
        onPressed: ShellState.togglePowerMenu()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "launcher"
        description: "Toggle the BrutalDots application launcher"
        onPressed: ShellState.openLauncher("apps")
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "keepAwake"
        description: "Toggle the idle inhibitor"
        onPressed: Idle.toggleInhibit()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "darkMode"
        description: "Flip between the light and dark palettes"
        onPressed: Theme.toggleDark()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "nightLight"
        description: "Toggle the night light"
        onPressed: NightLight.toggle()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "lock"
        description: "Lock the session"
        onPressed: ShellState.locked = true
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "clipboard"
        description: "Toggle the BrutalDots clipboard picker"
        onPressed: ShellState.openLauncher("clipboard")
    }

    // ── Capture ────────────────────────────────────────────────────────────
    GlobalShortcut {
        appid: "brutaldots"
        name: "screenshotRegion"
        description: "Screenshot a region"
        onPressed: Capture.region()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "screenshotScreen"
        description: "Screenshot the focused output"
        onPressed: Capture.screen()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "screenshotWindow"
        description: "Screenshot the active window"
        onPressed: Capture.window()
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "recordRegion"
        description: "Start or stop recording a region"
        onPressed: Capture.toggleRecording(true)
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "recordScreen"
        description: "Start or stop recording the screen"
        onPressed: Capture.toggleRecording(false)
    }

    GlobalShortcut {
        appid: "brutaldots"
        name: "pickColour"
        description: "Pick a colour into the clipboard"
        onPressed: Capture.pickColour()
    }
}
