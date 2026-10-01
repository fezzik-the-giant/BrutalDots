pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * User-editable configuration, persisted as JSON.
 *
 * Lives at ~/.config/brutaldots/settings.json. The file is watched, so editing
 * it by hand updates the shell live; writing through the adapter from QML
 * persists back to disk. Everything the user might reasonably want to change
 * belongs here rather than baked into a module.
 */
Singleton {
    id: root

    readonly property string configDir: `${Quickshell.env("HOME")}/.config/brutaldots`
    readonly property alias data: adapter

    function save(): void {
        file.writeAdapter();
    }

    /// True once the file has been read (or found missing). Anything that must
    /// not act on default values should wait for this.
    property bool ready: false

    // Reload and write are both debounced. Writing the adapter changes the
    // file, which fires the watcher, which reloads the adapter, which counts
    // as an update — without a gap between them that is a loop.
    Timer {
        id: reloadDebounce
        interval: 100
        onTriggered: file.reload()
    }

    Timer {
        id: writeDebounce
        interval: 100
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file

        path: `${root.configDir}/settings.json`
        watchChanges: true
        // No preload: a blocking read happens as soon as `path` is assigned,
        // which is before the adapter below exists, and the parsed values then
        // have nothing to land on — the shell silently runs on defaults.
        // A missing file is the expected first-run state, not an error worth
        // printing; anything else is reported below.
        printErrors: false

        onLoaded: root.ready = true
        onFileChanged: reloadDebounce.restart()
        onAdapterUpdated: writeDebounce.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeDebounce.restart();
            else console.warn("Settings: could not read", this.path, "-",
                FileViewError.toString(error));
        }

        adapter: JsonAdapter {
            id: adapter

            // ── Identity ───────────────────────────────────────────────────
            property string userName: Quickshell.env("USER") || "user"
            property string avatar: ""
            property string statusText: "Online"

            // ── Appearance ─────────────────────────────────────────────────
            property JsonObject theme: JsonObject {
                // Inverts the neutrals: ink becomes cream and the surfaces
                // become near-black. The accents do not move — what flips is
                // the ink drawn on them. See Config/Theme.qml.
                property bool dark: false

                // Whether flipping the above also sets the GTK colour scheme.
                // Off keeps your GTK settings your own; everything else still
                // follows the toggle. See Services/Toolkit.qml.
                property bool syncApps: true
            }

            // ── Weather ────────────────────────────────────────────────────
            // Any name Open-Meteo's geocoder understands. Blank = auto-locate.
            property string weatherLocation: ""
            property bool weatherMetric: true

            // ── Applications launched by the shell ─────────────────────────
            property JsonObject apps: JsonObject {
                property string terminal: "kitty"
                property string browser: "firefox"
                property string files: "nautilus"
                property string editor: "code"
                property string music: "spotify"
                property string chat: "discord"
            }

            // ── Bar ────────────────────────────────────────────────────────
            property JsonObject bar: JsonObject {
                property int height: 42
                property int sideMargin: 20
                property int topMargin: 10
                property bool showMedia: true

                // Tray. Passive items are shown by default because plenty of
                // applications mislabel a useful icon; list StatusNotifierItem
                // ids here to hide specific ones.
                property bool trayHidePassive: false
                property list<var> trayIgnored: []
            }

            // ── Idle and lock ──────────────────────────────────────────────
            // Seconds of inactivity before each step. 0 disables that step.
            // BrutalDots does its own idle handling, so there is no hypridle
            // config to keep in sync.
            property JsonObject idle: JsonObject {
                property int dimAfter: 300
                property int lockAfter: 600
                property int screenOffAfter: 900
                property int suspendAfter: 0
                property real dimOpacity: 0.55

                // Hold every step off while a fullscreen window is focused.
                // Wayland's idle timer only counts input the compositor
                // routes, and a gamepad goes straight from evdev to the game —
                // so without this, a controller session dims, then locks,
                // mid-play.
                property bool inhibitFullscreen: true
            }

            property JsonObject lock: JsonObject {
                // Name of a file in /etc/pam.d used to check the password.
                property string pamConfig: "login"
                property string message: ""
            }

            // ── Wallpaper ──────────────────────────────────────────────────
            // Drawn by the shell, so no swww/hyprpaper/swaybg daemon is
            // needed. Turn `enabled` off if you would rather run one.
            property JsonObject wallpaper: JsonObject {
                property bool enabled: true

                // Image to show. Blank falls back to $BRUTALDOTS_WALLPAPER,
                // then ~/.config/brutaldots/wallpaper, then the pattern below.
                property string path: ""
                property string mode: "fill"  // fill | fit | stretch | center | tile

                // Where the picker looks: this folder and its immediate
                // subfolders.
                property string directory: "~/Pictures/Wallpapers"

                // Used when there is no image: grid | dots | diagonal | solid
                property string pattern: "grid"
                property int patternSpacing: 44
                property real patternOpacity: 0.06
            }

            // ── Media ──────────────────────────────────────────────────────
            property JsonObject media: JsonObject {
                // The visualiser reads the output device through cava, so it
                // follows anything audible — not just players that publish
                // MPRIS metadata. Without cava installed the mini player still
                // works; it just draws a flat baseline.
                property bool visualizer: true
                property int visualizerBars: 28
                property int visualizerSmoothing: 20  // cava noise_reduction
            }

            // ── Night light ────────────────────────────────────────────────
            property JsonObject nightLight: JsonObject {
                property int temperature: 4000
                property bool scheduleSunset: false
                property bool scheduleCustom: false
                property int customOn: 20
                property int customOff: 7
            }

            // ── Screenshots and recordings ─────────────────────────────────
            property JsonObject capture: JsonObject {
                property string directory: ""          // blank = XDG Pictures
                // Open the shot in an annotation tool instead of saving it
                // straight away. satty or swappy, whichever is installed.
                property bool annotate: false
            }

            // ── Desktop widget layer ───────────────────────────────────────
            property JsonObject widgets: JsonObject {
                // "top"    - floats above normal windows, so the toggle is visible
                // "bottom" - true desktop widgets, sitting under every window
                property string layer: "top"
            }

            // ── Quick links shown in the dashboard ─────────────────────────
            property list<var> quickLinks: [
                { "name": "GitHub",   "icon": "github",   "color": "grey",     "url": "https://github.com" },
                { "name": "Reddit",   "icon": "reddit",   "color": "coral",    "url": "https://reddit.com" },
                { "name": "YouTube",  "icon": "youtube",  "color": "red",      "url": "https://youtube.com" },
                { "name": "WhatsApp", "icon": "whatsapp", "color": "green",    "url": "https://web.whatsapp.com" },
                { "name": "Gmail",    "icon": "mail",     "color": "pink",     "url": "https://mail.google.com" },
                { "name": "Twitch",   "icon": "twitch",   "color": "lavender", "url": "https://twitch.tv" }
            ]

            // ── Pomodoro (minutes) ─────────────────────────────────────────
            property JsonObject pomodoro: JsonObject {
                property int focus: 25
                property int shortBreak: 5
                property int longBreak: 15
                property int roundsBeforeLong: 4
            }
        }
    }
}
