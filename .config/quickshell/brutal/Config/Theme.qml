pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

/// Design tokens. Everything visual in the shell resolves through here.
///
/// Dark mode inverts the neutrals only; the accents do not move. See
/// AGENTS.md "The design" for why, and for the contrast floors any change
/// here has to keep.
Singleton {
    id: root

    /// Persisted in settings.json, so the choice survives a restart.
    readonly property bool dark: Settings.data.theme.dark

    function setDark(on: bool): void { Settings.data.theme.dark = on; }
    function toggleDark(): void { Settings.data.theme.dark = !Settings.data.theme.dark; }

    // ── Palette ────────────────────────────────────────────────────────────
    /// The live fill ramp. Everything that paints a block reads this.
    readonly property QtObject color: root.dark ? root.paletteDark : root.paletteLight

    /// Accents for drawing *on* a surface, where the colour is the mark
    /// itself rather than the block behind it. Identical to `color`'s accents
    /// now that those no longer invert; kept because the distinction is real.
    readonly property QtObject mark: root.paletteLight

    /// Sampled from the Bruteon previews: Material 100-200 pastels laid over a
    /// warm linen base, with a single near-black used for ink, borders, shadows.
    readonly property QtObject paletteLight: QtObject {
        id: lightSet

        // Neutrals, lightest to darkest
        readonly property color base: "#FAF0E6"      // raised cards, inputs
        readonly property color surface: "#F5EBE6"   // default panel fill
        readonly property color mantle: "#EFE0D6"    // recessed / page background
        readonly property color crust: "#E8E0D0"     // bar islands
        readonly property color ink: "#161110"       // borders and text
        /// Darkened to clear AA on the darkest light neutral. #857E7B
        /// measured 3.04:1 on crust and had never been checked.
        readonly property color subtext: "#686361"   // secondary text
        readonly property color overlay: "#99000000" // scrim behind dashboards (#AARRGGBB)
        /// Cast shadows. Light mode can use the ink itself; dark mode cannot.
        readonly property color shadow: "#161110"

        // Pastel accents
        readonly property color red: "#FF8A80"
        readonly property color coral: "#FFAB91"
        readonly property color salmon: "#FFB3A1"
        readonly property color orange: "#F79E5D"
        readonly property color peach: "#FFCC80"
        readonly property color yellow: "#F2DC8F"
        readonly property color green: "#C5E1A5"
        readonly property color mint: "#A5D6A7"
        readonly property color teal: "#80CBC4"
        readonly property color blue: "#90CAF9"
        readonly property color lavender: "#D1C4E9"
        readonly property color purple: "#CE93D8"
        readonly property color pink: "#FFCBD5"
        readonly property color grey: "#E0E0E0"

        // Semantic aliases
        readonly property color accent: lightSet.orange
        readonly property color ok: lightSet.green
        readonly property color warn: lightSet.peach
        readonly property color danger: lightSet.red
    }

    /// The same palette after dark. Derived rather than picked: each accent
    /// keeps the hue of its pastel and is pulled down until cream text clears
    /// WCAG AA on it — the whole set lands between 4.5:1 and 7:1 against `ink`,
    /// so a label on a coloured block is legible in every mode the shell can be
    /// in. The five warm ones are spread apart in lightness on top of that,
    /// because at one fixed contrast red, coral, salmon, orange and peach
    /// collapse into the same brown.
    ///
    /// The neutrals keep the linen warmth — these are brown-blacks, not grey
    /// ones — and hold their order, so `base` is still the lightest and a
    /// raised card still reads as raised. The scrim goes a little heavier: it
    /// covers the same wallpaper, but now with a dark panel in front of it.
    readonly property QtObject paletteDark: QtObject {
        id: darkSet

        // The ramp sits a step higher than a dark theme normally would, so a
        // black shadow has something to be darker than. Do not lower it
        // without re-checking subtext and grey — see AGENTS.md.
        readonly property color base: "#3E342F"
        readonly property color surface: "#332B27"
        readonly property color mantle: "#2A2320"
        readonly property color crust: "#201A17"
        readonly property color ink: "#F4EADF"
        /// Lightened with the ramp; #968B83 would be 3.64:1 on the new base.
        readonly property color subtext: "#A69D96"
        readonly property color overlay: "#B3000000"
        /// Pure black, not the ink: the ink is cream here, and a shadow
        /// lighter than its surface is a highlight.
        readonly property color shadow: "#000000"

        // By reference, not copy: these are not a dark-mode variant of the
        // accents, they are the accents.
        readonly property color red: lightSet.red
        readonly property color coral: lightSet.coral
        readonly property color salmon: lightSet.salmon
        readonly property color orange: lightSet.orange
        readonly property color peach: lightSet.peach
        readonly property color yellow: lightSet.yellow
        readonly property color green: lightSet.green
        readonly property color mint: lightSet.mint
        readonly property color teal: lightSet.teal
        readonly property color blue: lightSet.blue
        readonly property color lavender: lightSet.lavender
        readonly property color purple: lightSet.purple
        readonly property color pink: lightSet.pink
        /// Lifted with the ramp; #4A4442 was 1.26:1 against the new base.
        readonly property color grey: "#595352"

        readonly property color accent: darkSet.orange
        readonly property color ok: darkSet.green
        readonly property color warn: darkSet.peach
        readonly property color danger: darkSet.red
    }

    /// Ordered accent list, used anywhere something needs "the next colour"
    /// (workspace pips, cava bars, quick-link tiles).
    readonly property list<color> accents: [
        root.color.salmon,
        root.color.green,
        root.color.blue,
        root.color.lavender,
        root.color.peach,
        root.color.pink,
        root.color.mint,
        root.color.purple
    ]

    /// Resolve a palette name from settings.json ("coral") to a colour.
    /// Falls back to the accent so a typo degrades instead of rendering black.
    function named(name: string): color {
        const c = root.color;
        switch (name) {
            case "red": return c.red;
            case "coral": return c.coral;
            case "salmon": return c.salmon;
            case "orange": return c.orange;
            case "peach": return c.peach;
            case "yellow": return c.yellow;
            case "green": return c.green;
            case "mint": return c.mint;
            case "teal": return c.teal;
            case "blue": return c.blue;
            case "lavender": return c.lavender;
            case "purple": return c.purple;
            case "pink": return c.pink;
            case "grey": return c.grey;
            case "base": return c.base;
            default: return c.accent;
        }
    }

    /// Relative luminance (WCAG). QML hands over gamma-encoded sRGB in 0..1.
    function luminance(c: color): real {
        const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    /// The ink that reads on `fill`. Measured, not looked up, so it is right
    /// for any fill in either mode — including a hover state part-way between
    /// two colours. BrutalBox exposes this as `onColor`.
    function inkOn(fill: color): color {
        const l = root.luminance(fill);
        const ratio = ink => {
            const li = root.luminance(ink);
            return (Math.max(l, li) + 0.05) / (Math.min(l, li) + 0.05);
        };
        return ratio(root.paletteLight.ink) >= ratio(root.paletteDark.ink)
            ? root.paletteLight.ink
            : root.paletteDark.ink;
    }

    /// Fill for a hovered control. Light mode presses the fill toward the ink;
    /// dark mode lifts it away, because darkening something already this close
    /// to black produces no change anyone can see.
    function hover(c: color): color {
        return root.dark ? Qt.lighter(c, 1.35) : Qt.darker(c, 1.06);
    }

    // ── Geometry ───────────────────────────────────────────────────────────
    readonly property QtObject radius: QtObject {
        readonly property int xs: 6
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 14
        readonly property int xl: 18
        readonly property int pill: 999
    }

    readonly property QtObject border: QtObject {
        readonly property int width: 2
        readonly property int thick: 3
        readonly property color color: root.color.ink
    }

    /// Hard offset shadows. No blur, no alpha ramp — that is the whole point.
    /// The colour comes from the palette, not from `ink`; see AGENTS.md.
    readonly property QtObject shadow: QtObject {
        readonly property int sm: 3
        readonly property int md: 4
        readonly property int lg: 6
        readonly property color color: root.color.shadow
    }

    /// Bar geometry. Every chip, button and cluster inside an island is this
    /// tall, so the three islands come out the same height — otherwise each is
    /// sized by whatever happens to sit in it, and they disagree by a few
    /// pixels that are very visible once you notice them.
    readonly property QtObject bar: QtObject {
        readonly property int control: 34
        /// Icons drawn inside those controls (tray icons, workspace app icons).
        readonly property int glyph: 20
    }

    readonly property QtObject space: QtObject {
        readonly property int xs: 4
        readonly property int sm: 6
        readonly property int md: 10
        readonly property int lg: 14
        readonly property int xl: 20
        readonly property int xxl: 28
    }

    // ── Type ───────────────────────────────────────────────────────────────
    readonly property QtObject font: QtObject {
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property string display: "JetBrainsMono Nerd Font"
        readonly property QtObject size: QtObject {
            readonly property int xs: 9
            readonly property int sm: 10
            readonly property int md: 11
            readonly property int lg: 13
            readonly property int xl: 17
            readonly property int xxl: 22
            /// The dashboard clock, and nothing else — it is the one number on
            /// screen that is meant to be read from across the room.
            readonly property int huge: 42
        }
        /// The bar is glanced at from across the screen, not read up close like
        /// a panel you have deliberately opened, so it runs one step above the
        /// scale above. Kept separate rather than enlarging `size`, which every
        /// dialog, launcher row and dashboard card also uses.
        readonly property QtObject barSize: QtObject {
            readonly property int xs: 11
            readonly property int sm: 12
            readonly property int md: 13
            readonly property int lg: 15
            readonly property int xl: 19
        }

        /// Nerd Font glyphs, which are drawn as text but are not text.
        ///
        /// A glyph at the same pixelSize as the label beside it reads smaller,
        /// because its ink fills less of the em box than a letter does — the
        /// bar's glyphs measured 11px of ink at 15px while the app-icon images
        /// next to them were 20px. This scale is what closes that gap, and it
        /// is separate from `size`/`barSize` so growing an icon never grows the
        /// text around it.
        readonly property QtObject icon: QtObject {
            readonly property int xs: 13
            readonly property int sm: 15
            readonly property int md: 18
            readonly property int lg: 22
            readonly property int xl: 26
        }

        readonly property QtObject weight: QtObject {
            readonly property int normal: Font.Normal
            readonly property int medium: Font.Medium
            readonly property int bold: Font.Bold
            readonly property int black: Font.ExtraBold
        }
    }

    // ── Motion ─────────────────────────────────────────────────────────────
    // Brutalism is blunt: short durations, no easing theatrics.
    readonly property QtObject anim: QtObject {
        readonly property int fast: 90
        readonly property int normal: 150
        readonly property int slow: 250
        readonly property int curve: Easing.OutQuad
    }
}
