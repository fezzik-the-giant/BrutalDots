pragma Singleton

import Quickshell
import QtQuick

/**
 * Nerd Font glyphs, named once so modules never hard-code a codepoint.
 * All are Material Design Icons (nf-md-*) unless noted; the brands at the
 * bottom are Font Awesome. `named()` is what settings.json resolves through.
 */
Singleton {
    id: root

    // Power / session
    readonly property string power: "󰐥"
    readonly property string restart: "󰜉"
    readonly property string logout: "󰍃"
    readonly property string lock: "󰌾"
    readonly property string sleep: "󰤄"

    // Media
    readonly property string play: "󰐊"
    readonly property string pause: "󰏤"
    readonly property string next: "󰒭"
    readonly property string previous: "󰒮"
    readonly property string music: "󰝚"

    // Status
    readonly property string volumeHigh: "󰕾"
    readonly property string volumeMed: "󰖀"
    readonly property string volumeLow: "󰕿"
    readonly property string volumeMute: "󰝟"
    readonly property string micOn: "󰍬"
    readonly property string micOff: "󰍭"
    readonly property string bluetooth: "󰂯"
    readonly property string bluetoothOff: "󰂲"
    readonly property string wifi: "󰖩"
    readonly property string wifiOff: "󰖪"

    /// Signal strength, weakest to strongest. The menu picks one per network;
    /// the bar keeps using the plain `wifi` glyph so the island stays steady
    /// instead of flickering between bars as the signal drifts.
    readonly property list<string> wifiBars: [
        "󰤟", "󰤢", "󰤥", "󰤨"
    ]
    readonly property list<string> wifiBarsLock: [
        "󰤡", "󰤤", "󰤧", "󰤪"
    ]
    readonly property string ethernet: "󰈀"
    readonly property string battery: "󰁹"
    readonly property string clock: "󰥔"
    readonly property string bell: "󰂚"
    readonly property string bellOff: "󰂛"

    // System
    readonly property string cpu: "󰻠"
    readonly property string ram: "󰍛"
    readonly property string disk: "󰋊"
    readonly property string os: "󰣇"
    readonly property string wm: "󰖯"
    readonly property string shell: "󰆍"
    readonly property string host: "󰟀"
    readonly property string uptime: "󰅐"
    readonly property string packages: "󰏗"
    readonly property string specs: "󰇄"

    // Apps / launcher
    readonly property string terminal: "󰆍"
    readonly property string browser: "󰈹"
    readonly property string files: "󰉋"
    readonly property string editor: "󰏫"
    readonly property string chat: "󰙯"
    readonly property string appGrid: "󰀻"

    // Widgets
    readonly property string tasks: "󰄲"
    readonly property string check: "󰄬"
    readonly property string star: "󰓎"
    readonly property string plus: "󰐕"
    readonly property string minus: "󰍴"
    readonly property string close: "󰅖"
    readonly property string trash: "󰩹"
    readonly property string pencil: "󰏫"
    readonly property string calendar: "󰃭"
    readonly property string timer: "󰔟"
    readonly property string refresh: "󰑐"
    readonly property string settings: "󰒓"
    readonly property string theme: "󰔎"
    readonly property string chevronLeft: "󰅁"
    readonly property string chevronRight: "󰅂"
    readonly property string location: "󰍎"

    // Weather
    readonly property string sun: "󰖙"
    readonly property string moon: "󰖔"
    readonly property string cloud: "󰖐"
    readonly property string rain: "󰖗"
    readonly property string snow: "󰖘"
    readonly property string storm: "󰙾"
    readonly property string fog: "󰖑"
    readonly property string humidity: "󰖎"
    readonly property string wind: "󰖝"

    // Battery — indexed by tenths, so entry 0 is empty and entry 10 is full.
    /// Discharging or idle.
    readonly property list<string> batteryLevel: [
        "󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"
    ]

    /// On mains.
    readonly property list<string> batteryCharging: [
        "󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"
    ]

    // Launcher, clipboard, capture, session
    readonly property string search: "󰍉"
    readonly property string clipboard: "󰨸"
    readonly property string copy: "󰆏"
    readonly property string history: "󰋚"
    readonly property string emoji: "󰇲"
    readonly property string screenshot: "󰹑"
    readonly property string camera: "󰄀"
    readonly property string record: "󰻃"
    readonly property string recordStop: "󰙧"
    readonly property string colorPicker: "󰈋"
    readonly property string video: "󰕧"
    readonly property string image: "󰋩"
    readonly property string crop: "󰆟"
    readonly property string coffee: "󰛊"
    readonly property string nightLight: "󰃝"
    readonly property string shield: "󰳌"
    readonly property string fingerprint: "󰈷"
    readonly property string lockOutline: "󰍁"
    readonly property string account: "󰀉"
    readonly property string tray: "󱊔"
    readonly property string chevronUp: "󰅃"
    readonly property string chevronDown: "󰅀"
    readonly property string openExternal: "󰏌"
    readonly property string keyboard: "󰌌"
    readonly property string monitor: "󰍹"
    readonly property string headphones: "󰋋"
    readonly property string laptop: "󰌢"
    readonly property string mouse: "󰍽"
    readonly property string cellphone: "󰄜"
    readonly property string devices: "󰾰"
    readonly property string bluetoothConnected: "󰂱"
    readonly property string alert: "󰀪"
    readonly property string info: "󰋽"
    readonly property string checkCircle: "󰗡"
    readonly property string commandLine: "󰞷"
    readonly property string rocket: "󱓟"
    /// nf-md-view_dashboard — the dashboard's own overview tab.
    readonly property string dashboard: "󰕮"
    /// nf-md-brightness_5 — the dim step of the idle ladder. The same
    /// glyph as `brightnessLow`; two names because they are two ladders.
    readonly property string dim: "󰃞"
    /// The brightness ladder, mirroring volumeLow/Med/High above.
    readonly property string brightnessLow: "󰃞"
    readonly property string brightnessMed: "󰃟"
    readonly property string brightnessHigh: "󰃠"
    /// nf-md-monitor_off — the screen-off step.
    readonly property string monitorOff: "󰶐"
    readonly property string batteryAlert: "󰂃"

    /// Brand marks, the one place this file is not nf-md-*. Font Awesome
    /// carries the recognisable logos; MDI's equivalents are generic shapes.
    /// nf-fa-github
    readonly property string github: ""
    /// nf-fa-reddit
    readonly property string reddit: ""
    /// nf-fa-youtube_play
    readonly property string youtube: ""
    /// nf-fa-whatsapp
    readonly property string whatsapp: ""
    /// nf-fa-twitch
    readonly property string twitch: ""
    /// nf-fa-envelope
    readonly property string mail: ""

    /// Resolve an icon field written in settings.json: either a name from this
    /// file ("youtube"), or a literal glyph, which passes through untouched so
    /// a hand-picked codepoint still works and older configs keep running.
    function named(name: string): string {
        if (!name)
            return "";
        const glyph = root[name];
        // A glyph is one character, or two when it is a surrogate pair — which
        // every nf-md-* here is. Anything longer is some other property of this
        // singleton that happens to share the name, not an icon.
        return (typeof glyph === "string" && glyph.length > 0 && glyph.length <= 2)
            ? glyph
            : name;
    }
}
