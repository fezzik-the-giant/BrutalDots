# BrutalDots — working notes

Context for anyone (human or agent) changing this repo. `README.md` is for
people *using* BrutalDots; this file is for people editing it.

**What belongs where.** A code comment answers "what do I need to know to edit
*this line* without breaking it" — an invariant, a gotcha, an API quirk, a
magic number. Everything else lives here: why the system is shaped this way,
rules that span files, measurements, and the history behind a decision that
looks arbitrary. If a comment is more than a few lines of reasoning, it
probably wants to be a section here with a one-line pointer left behind.

---

## Layout

`.config/` is a literal mirror of `~/.config`: what is in it is what lands
there, at the same path. Anything that installs somewhere else lives at the
root, which is why `sddm/` is not in there — it installs to `/usr/share` and
`/etc`, and putting it under `.config/` would make the mirror a lie.

| Path | What it is |
| --- | --- |
| `.config/quickshell/brutal/` | The shell. `Config/` tokens and settings, `Services/` singletons, `Modules/` UI, `Components/` the `Brutal*` widget set. |
| `.config/hypr/` | Hyprland config. **Lua only** — see below. |
| `.config/kitty/`, `.config/starship.toml`, `.config/fastfetch/`, `.config/nvim/` | Terminal-side theming. |
| `sddm/` | The login screen, assembled from the shell at install time. Installs system-wide. |
| `scripts/` | `test-nested.sh` (nested compositor), `test-sddm.sh` (greeter under QtTest). |
| `install.sh` | The entrypoint: flags, then the run, in the order it happens. |
| `install/` | The installer's modules, sourced by it. `common` output helpers, `banner` the title card, `greeter` assemble/install/remove the SDDM theme, `checklist` the feature picker, `uninstall`, `packages` dependencies and the zsh setup, `shell` the Quickshell and Hyprland config, `terminal` kitty/starship/fastfetch/nvim. |

---

## The design

Four rules, applied without exception:

1. Every surface is opaque.
2. Every surface has a 2px border in the ink colour.
3. Every surface casts a hard, un-blurred, offset shadow.
4. Colour is used in flat blocks, never gradients.

### Dark mode inverts the neutrals only

`ink` becomes the cream and the surfaces become near-black. **The accents do
not move** — the same pastels are used in both modes, and what flips is the ink
drawn on top of them.

It used to invert the accents too, into deep tones dark enough to carry cream
text. That was a tidier rule and it looked worse: a fill dark enough for cream
ink is a fill with the life drained out of it, so every accent came out muted.
The pastels sit at 5.06–13.02:1 against the dark surfaces; the deep set managed
1.45–2.25:1.

The consequence is that **a component drawing on a coloured fill cannot assume
`color.ink`.** `BrutalBox` exposes `onColor`, and `BrutalText`/`BrutalIcon`
walk up the parent chain to the nearest box and use it automatically.

A **see-through fill defines nothing** — whatever is behind it does. `transparent`
is `#00000000`, so measuring one reads it as pure black and answers cream, which
is invisible on a light surface. `BrutalBox.onColor` therefore defers to the
plain ink when its own fill is see-through, and the inheritance walk skips such
boxes to find the real surface behind them. This is what made the tray menu
white-on-white in light mode: its rows are `BrutalButton`s with
`baseColor: "transparent"`.

That inheritance is deliberate rather than a value threaded through each call
site. A fill is often a conditional (`open ? mint : green`), and a component
that hard-codes `Theme.color.ink` on a coloured fill is only wrong in *one*
mode, so it survives review. Two separate attempts at this change missed sites
for exactly that reason — grep cannot find them reliably. Making the default
correct removes the class. Override `color` explicitly only when the thing
drawn is not on its ancestor box at all — a day number over a sibling "today"
dot.

**A border inside a coloured fill is subject to the same rule.** `Theme.border`
is the ink for a surface sitting on the *background*, and in dark mode that ink
is the cream. A box nested inside an accent — the clock's AM/PM chip inside its
lavender — is delineated against that accent instead, so it takes
`parent.onColor`. Left on the default it measures 1.38:1 against the lavender in
dark mode and effectively disappears, while the letters inside it, which do walk
the parent chain, stay dark. `onColor` gives both 11.4:1 in either mode.

### Shadows do not follow the ink

`shadow.color` used to be `root.color.ink`. That worked in light mode by
coincidence — ink *is* the darkest colour there, so "shadow = ink" and "shadow =
darker than everything" were the same rule. Inverting the ramp broke the
coincidence and dark mode started casting cream shadows, which read as a glow.

A cast shadow must be darker than what it falls on, and below near-black there
is nothing darker to be. The dark ramp therefore sits higher than a dark theme
normally would: against the old surfaces a black shadow managed 1.09:1 on the
bar islands, and lifting every surface one step buys 1.22:1 there and 1.74:1 on
a card. That is the ceiling. Light mode gets 14.5:1 for free and this will
never match it.

Lifting the ramp forced two knock-on corrections: `subtext` would have dropped
to 3.64:1 (under AA), and the `grey` accent collapsed to 1.26:1 against the new
base and stopped reading as a block.

### Icons have their own size scale

`Theme.font.icon`, separate from `size`/`barSize`. A Nerd Font glyph is drawn
as text but is not text: at the same `pixelSize` as the label beside it, its ink
fills less of the em box and reads noticeably smaller. The bar's glyphs measured
**11px of ink at 15px**, while the app-icon *images* next to them were 20px —
which is what made the icons look undersized.

Keeping the scale separate is the point: growing an icon must never grow the
text around it. Bar controls are fixed at `Theme.bar.control`, so a larger glyph
fills more of a fixed box rather than growing the island.

### Icons are named, never spelled

Every glyph in the shell comes from `Config/Icons.qml`, and anything that
selects one — including `settings.json` — says a *name*. `Icons.named()`
resolves it, and passes an unrecognised string through unchanged, so a
hand-picked codepoint in a user's settings still renders and no config needs
migrating.

The reason is that a codepoint is unreviewable. The `quickLinks` default
carried `\uF167` for YouTube, which is **`fa-cloudsmith`** — a diamond. It sat
there through several passes of the glyph audit, because that audit checks the
*names* in `Icons.qml` against the font and a raw literal has no name to check.
Nothing about `"\uF167"` looks wrong until it is on screen.

The colour field beside it was already doing this right: `Theme.named("red")`.
Two conventions in one object literal, and the failure landed on the one that
skipped the lookup.

A persisted value shadows the QML default, so changing a default alone does not
reach an existing install — the YouTube fix had to be applied to
`~/.config/brutaldots/settings.json` as well.

### A glyph is wider than the cell it advances

`fa-youtube_play` paints 987 units of ink inside a 600-unit advance, and it is
not an outlier: 93 of the 114 glyphs in `Icons.qml` overflow their advance, all
of them to the right (`lsb` is 0, so the ink starts at the cell's left edge and
runs past its right).

That matters because `Text.AlignHCenter` centres the **advance**, while Qt
sizes the item to the **ink**. The two disagree by half the overflow, so a
centred icon lands that far right of centre — 3-5px at `icon.xl`, which is what
made the dashboard's quick-link glyphs look off next to their labels. The
labels are fine because a word's ink and advance agree (`"GitHub"`: 90 vs
93.56, a 0px correction).

`BrutalIcon` corrects it by translating the paint, not the item, so no layout
geometry changes and a stretched icon stays right. Verified on the bar: the
power glyph sat 1px right of its button's centre and now sits on it.

### Contrast floors

- Ink on any accent: **≥4.5:1** (currently 7.84–14.18).
- `subtext` on any surface: **≥4.5:1**. `crust` binds this, not `base`: for
  dark ink the *darkest* neutral is the hardest background. The light value
  was corrected from `#857E7B`, which measured 3.04-3.54:1 — the dark value
  was retuned when the dark ramp was lifted and the light one was never
  revisited, so the floor was asserted here from a dark-mode exercise alone.
  `#686361` clears 4.51:1 on `crust` and 5.27:1 on `base`. It sits closer to
  the ink than the old value did, and that is the cost: lightening it back
  for hierarchy puts 9px text under AA again.
- An accent block against the surface behind it: below ~1.35 it stops reading
  as a block.

`Theme.inkOn(fill)` *measures* rather than looks up, so it is correct for any
fill in either mode — a pastel accent, a near-black surface, or a hover state
part-way between two colours.

---

## Dark mode propagation

`Theme.dark` is backed by `settings.json`. Flipping it must reach five places,
and the trigger for all of them lives in `shell.qml` — **not** inside the
services — because a Quickshell singleton is only constructed the first time
something reads it. A service nobody reads never runs.

| Target | Mechanism |
| --- | --- |
| The shell | `Theme.color` swaps object identity, re-triggering every binding. |
| Hyprland | `Appearance.syncPalette()` → `hyprctl eval`. Borders take `ink`, shadows take `shadow.color`. |
| kitty | `Terminal.sync()` rewrites a one-line pointer file, then `pkill -USR1 -x kitty`. |
| The greeter | `Greeter.sync()` rewrites one line of `/var/lib/brutaldots/theme.conf`. |
| GTK / Qt / Electron | `Toolkit.sync()` sets `color-scheme` via `gsettings`. |

Startup pushes differ on purpose. Hyprland forgets on every `hyprctl reload`.
The greeter is pushed because installing while already dark leaves its state
file saying light. kitty's pointer is a file that persists, so it is not.

---

## Platform quirks

### Hyprland is configured in Lua, never `.conf`

This is a hard rule for the repo. Two consequences:

- `hyprctl keyword` **does not work** — "keyword can't work with non-legacy
  parsers. Use eval." Use `hyprctl eval 'hl.config({...})'`.
- A dispatch argument is **evaluated as Lua**. `hyprctl dispatch workspace 3`
  fails with `[string "return hl.dispatch(workspace 3)"]:1: ')' expected near
  '3'`. Use the dispatcher expression: `hl.dsp.focus({ workspace = 3 })`.

That second one is why `HyprlandWorkspace.activate()` cannot be used —
Quickshell implements it as `dispatch("workspace <id>")`, which fails
*silently*. `Idle` (dpms) and `Keybinds` (submap) hit the same wall and keep
the plain form as a fallback for anyone running the shell against a `.conf`
Hyprland.

Three more, all of which cost round trips when probing a running compositor:

- **`hyprctl eval` prints only `ok`.** Never the expression's value, and never
  a Lua error — a syntax error and a successful call are indistinguishable from
  the output, so a check that reads stdout proves nothing. A probe has to write
  its own result out (`io.open(path, "w")`) and be read back from there. It
  does accept statements as well as expressions: a bare
  `package.loaded["x"] = nil` takes effect, verified by reading a sentinel back.
- **There is no `hl.off`.** A subscription registered through `eval` lives
  until the config is re-read, so clean up an ad-hoc `hl.on` with
  `hyprctl reload`. That is safe for autostarts: a reload does **not** re-fire
  `hyprland.start`, measured by counting the processes `custom/execs.lua`
  launches before and after — identical.
- **`win.monitor` is not where the window is.** A window the compositor did not
  place reports the monitor that was *focused* when it opened, so use
  `hl.get_monitor_at(win.at.x, win.at.y)`. Observed with an XWayland client
  that positioned itself in absolute screen coordinates; recorded here rather
  than re-measured, since nothing in the repo now does this.

Replacing the Hyprland config is a **rename, not a delete-then-copy**.
Hyprland watches `hyprland.lua` and reloads the instant it changes; remove it
first and a running compositor reads the gap, puts "cannot open hyprland.lua"
on screen, and leaves it there until the next successful reload.

### Quickshell

- **Singletons are lazy.** See the propagation table above.
- **`DesktopEntries` scans asynchronously** and only starts once something
  touches it. The first read always returns empty and fills in a second or two
  later. Read `.values` directly so the binding stays subscribed.
- **`lastIpcObject` is the last *event* payload**, not a full client record.
  For some windows it carries no `class` at all (thunar's does not). Prefer
  `toplevel.wayland.appId`, which the foreign-toplevel protocol always fills.
- **`Process` tracks the pid it spawned.** Run a picker and an encoder as one
  `sh -c 'geom=$(slurp); exec wf-recorder'` and the tracked pid is the *shell*
  while the picker is open, so a stop signal lands on a shell blocked in a
  command substitution and does nothing. Two processes, one per job.
- **`Quickshell.iconPath(name, true)`** returns `""` when the icon is missing,
  and handles absolute paths. A window class is *not* an icon name: `kitty`
  and `org.gnome.Nautilus` resolve, `zen` and `thunar` do not.
  `Apps.iconForClass()` tries the theme first, then the desktop entry by id,
  exec basename, then name — considering only entries that actually carry an
  icon. Each step earns its place: a nautilus *window* hits the theme on its
  app id, while the configured command `nautilus` misses both the theme and the
  id and is only found by exec basename. It cannot use `StartupWMClass`;
  Quickshell 0.2.1 does not expose it.
- **A wheel notch is a *flick*, and flicks do not add up.** `Flickable` turns a
  wheel event into a velocity rather than a displacement, and a notch arriving
  mid-flick replaces that velocity instead of adding to it, so spinning the
  wheel saturates. Measured on a 4000px-tall Flickable: one notch moved it 58px
  and *ten* notches moved it 61px. `Components/WheelScroll.qml` moves
  `contentY` directly instead — the same ten notches move 1020px — and takes
  only `PointerDevice.Mouse`, because a touchpad's pixel deltas are the case
  Flickable already handles well.
- **A handler declared inside a Flickable is not parented to it.** Flickable's
  default property is its `contentItem`, so a `WheelHandler` written inside one
  has `parent` set to that plain `QQuickItem` and `parent as Flickable` is
  null. Nothing errors; the handler just silently scrolls nothing. Walk up the
  parent chain, the way `BrutalText.inheritedInk` does.
- **`focus` is a FINAL property on `QQuickItem`.** Naming a function `focus`
  gets you `Final member focus is overridden … The override won't be used`, and
  the call silently goes nowhere.

### Live-preview cost

`Appearance.set()` is called on every `onPositionChanged` of a slider drag —
mouse-poll rate. It applies through a leading-edge throttle with a trailing
flush so the value you release on always lands.

The *perceived* lag was never the process spawn, though. `SettingRow.value`
binds to `Appearance.value(id)`, which reads `values` — and `values` was
written **only** by a probe running 400 ms after the last change, shelling out
13 `hyprctl getoption` calls. The slider therefore had no live feedback at all
and jumped once the round trip finished. `set()` now writes the value
optimistically; the probe still runs and still wins.

---

## The launcher

Browsing and searching are different jobs and are ranked differently.

With **no query** every entry scores the same, so the order is launch count
first and then alphabetical. That is deliberate — the list settles into habit —
but the switch happens silently mid-list, which reads as arbitrary. The list
therefore labels it: `FREQUENT`, then `ALL APPS` at `Apps.frequentCount`.
Headings only appear while browsing; once there is a query the order is
relevance, not habit, and a "frequent" heading over it would be a lie.

**Never cap the browse list.** The results view is a virtualised `ListView`, so
a long list costs nothing to build and truncating one only hides applications.
A `maxResults` of 40 against 117 entries meant browsing stopped somewhere in
the F's. The cap now applies to fuzzy matches only.

The fuzzy tier is a subsequence match, and a naive one matches far too much —
"fire" found *Ghost of Tsushima DIRECTOR'S CUT*. It is now measured rather than
just tested: `Apps.subsequence` returns how wide the match is and whether every
matched character starts a word. A wide match is rejected as coincidence unless
it is an acronym, which is the one case where wide is correct — "gimp" against
*GNU Image Manipulation Program*.

## Media

**`playerctld` is a proxy, not a player.** It republishes whichever player is
current under its own bus name, so it appears in `Mpris.players` alongside the
real one with the same identity and the same track. `Players.all` filters it
out; left in, the source switcher lists everything twice.

`Players.active` is chosen by heuristic — playing first, then controllable,
then whatever exists — and that runs again on every change to the player list.
An explicit choice from the switcher therefore has to outrank it, which is what
`pinned` is for. The pin is cleared when the player it names disappears, so a
closed tab hands control back to the heuristic instead of leaving the panel
pointing at nothing.

To test any of this you need more than one player. `python-dbus` plus a GLib
loop is enough to stand up a fake one; the only trap is that
`dbus.service.BusName` must be assigned to something, because dropping the
reference releases the name immediately and the service runs on invisibly.

## The terminal

### One file serves both modes

Colour in a terminal is **always a background, never text**. `#90CAF9` as text
on cream is 1.7:1 and unreadable; the same blue as a fill under `#161110` ink
is 12:1. A pastel block with ink on it is legible whatever is behind it, so
every block is already mode-proof.

Marks that touch the terminal's own background — pill caps, the prompt mark,
fetch glyphs — use **ANSI indices**, which kitty repaints when the palette
flips.

### The two kitty palettes are inverted in lightness, on purpose

Light mode's `color1` is `#a50d00`; dark mode's is `#FF8A80`. They are *text*
colours for their background, so an index is always the readable end of its
hue. This is why the nvim colourscheme sources its syntax colours from these
files rather than inventing them — the editor and the terminal around it cannot
then drift.

It is also why indices cannot serve as pastel pill fills. Pills use truecolour
plus a fixed ink.

### starship

A palette entry **shadows starship's built-in colour name for the whole file**
— `bold red` resolves to the pastel once `[palettes.brutaldots]` defines `red`.
Numeric ANSI indices cannot be shadowed. The canonical key is `vimcmd_symbol`,
not `vicmd_symbol`.

### kitty

kitty refuses to include the same file twice and reports it as a configuration
*error dialog*, not a silent no-op. The mode pointer is therefore additive:
light is the *absence* of an include, dark is one `include` line.
`kitty.config.load_config()` swallows bad lines unless you pass
`accumulate_bad_lines=[]` — without it, a checker reports success on a broken
config.

### fastfetch

`{#...}` emits **raw SGR parameters**, so `{#1}` is *bold*, not colour 1. Hex
(`{#FF8A80}`) is not supported in 2.68.1. Colour is stripped when stdout is not
a TTY; use `--pipe false` to see it. `{all}` for packages counts every backend
it can find.

---

## The greeter

The theme is **assembled at install time**, not stored complete. `Theme.qml`,
`Icons.qml` and the `Brutal*` components touch no Quickshell type — they import
`qs.Config` and nothing else — so a copy with that one line removed behaves
identically. Copies, not a second hand-maintained set, is what stops the login
screen drifting from the desktop.

The generator fails loudly rather than silently: a theme missing half its
palette is worse than one that refuses to build, because you find out about the
first at the login screen.

### Facts established by probing the real greeter

- `config` **is** visible inside a QML singleton; values arrive as strings.
- Sibling components resolve implicitly even with a `qmldir` present, so only
  the singletons need declaring.
- Models expose **named roles** in delegates (`name`, `realName`; `name`,
  `file`, `comment`). Raw role integers have been renumbered between SDDM
  releases — a greeter that breaks on upgrade is one you cannot log in to fix.
- `sddm.canPowerOff`/`canReboot`/`canSuspend` are all **false in `--test-mode`**
  (no daemon), so a preview shows no power buttons.
- `visible: false` does **not** stop a text binding from evaluating.

### Configuration precedence

`/etc/sddm.conf` is read **last and outranks everything** in `sddm.conf.d/`.
A drop-in naming the theme would be written, look right, and do nothing.

`CompositorCommand` lives in **`[Wayland]`**, not `[General]`. Put it in the
wrong section and SDDM does not complain — it silently keeps its default, and
the only way to find out is to log out and read the journal. The installer
reads the section back out of SDDM's own shipped defaults rather than assuming.

### Multi-monitor

SDDM creates a greeter window per screen; that part works. On Wayland it does
not own the outputs — it launches a compositor and the greeter is a client of
it. Weston's **kiosk** shell binds a *client* to a single output, so every
window lands on the first monitor and the rest stay black. **desktop-shell**
honours the per-output fullscreen request. This is not optional: a login screen
on one of two monitors is a bug, not a preference.

desktop-shell brings its own panel, background and an **on-screen keyboard**;
`sddm/weston.ini` turns all three off. That keyboard is separate from Qt's
(`InputMethod=qtvirtualkeyboard`) — removing one does nothing about the other.

### Dark mode follows the session

The greeter runs as the `sddm` user and cannot read `$HOME` (`drwx--x---`), so
it never sees `settings.json`. It *can* read its own `theme.conf`, and SDDM
re-reads that at every greeter start. So the real file lives at
`/var/lib/brutaldots/theme.conf`, owned by you, with a symlink from the
root-owned theme directory.

Seed it from the **session**, not from the old `theme.conf`. Seeding from the
latter leaves the first logout after installing showing the wrong palette, with
nothing to correct it until the shell next starts.

---

## nvim

`Normal` sits on the colour kitty paints, so the editor blends into its own
terminal; floats are one step raised and sidebars one step recessed.

Mode is **watched**, not read once, so toggling repaints an already-open editor.
The watcher **re-arms on every event**: a writer that replaces a file rather
than writing through it — which is what an atomic save is — leaves the original
watch pointing at an inode that no longer exists.

---

## The installer

Conventions, all of which have a reason:

- **`install.sh` bootstraps itself, so the README can be one curl.** Piped into
  bash it has no file to locate itself by and cannot source `install/` or copy
  `.config/`, so it clones into `~/.cache/brutaldots/checkout` and re-execs the
  copy there. Three details that are easy to undo by accident:
  `${BASH_SOURCE[0]-}` needs the dash or `set -u` aborts before the check can
  run; the re-exec passes `< /dev/tty` because stdin is the script and the
  checklist would otherwise silently take defaults; and that redirect is
  guarded by *opening* `/dev/tty`, not `-r`, since with no controlling terminal
  the node exists and the open still fails with ENXIO.
- **The entrypoint stays readable in one sitting.** `install.sh` is flags and
  then the order the work happens in; every step is a function in `install/`.
  Modules are *sourced*, not run: they share the globals set at the top and the
  helpers in `common.sh`, neither of which survives a subprocess. A module only
  defines things, so the source order is arbitrary and the run order is the
  list at the bottom of the entrypoint — that list is the file's real content.
- **`run_uninstall` guards itself.** It checks `$ACTION` internally and returns
  immediately otherwise, so the entrypoint calls it unconditionally and there
  is one place, not two, that knows what `--uninstall` means.
- **Nothing is deleted without being moved aside first.** A wrong guess about
  which backup to restore is still recoverable.
- **Idempotent.** Re-running adds nothing twice and does not re-back-up its own
  output. Shell rc files go through `rc_backup`, which enforces both halves of
  that: it never copies a file this run created — that would leave a backup of
  our own template — and it copies a file it has already backed up only once,
  so the kept copy is the one from before the first edit rather than one taken
  between two of ours. Two loops append to the same `.zshrc`, so without this a
  single run left two backups, the second already containing the prompt block.
- **The packages are required, not suggested.** `check_group` collects what is
  absent and `install_missing` brings the whole set in with one pacman call.
  There is no opt-out flag: the desktop is opinionated about what it contains,
  and coming up half-lit is worse than taking a minute to install. Anyone who
  installed the set by hand never reaches that code, which is also why a
  non-Arch machine is only turned away when something is genuinely missing.
- **The runtime guards stay anyway.** Every startup line and every shell action
  still tests for its own tool, so a package removed *after* installing
  switches its feature off rather than breaking the shell.
- **sudo for the greeter, the packages, and `chsh`**, each announced before it
  happens.
- **`setup_zsh` runs before the rc blocks, and that order is load-bearing.**
  Both rc loops are `[[ -e "$rc" ]] || continue`, so on a machine that has never
  run zsh there is no `~/.zshrc` for the prompt and the fetch to append to and
  they are skipped in silence — the prompt simply never appears and nothing says
  why. The seeded file is deliberately tiny (history, completion, `bindkey -e`):
  enough that zsh is usable rather than merely present, which is the difference
  between adopting the shell and stranding someone in it. An existing `.zshrc`
  is never rewritten.
- **The flag surface is deliberately small.** Anything the checklist can ask,
  the checklist owns — there is no `--sddm` to contradict it — and anything the
  running shell can toggle is not an install-time decision, which is why there
  is no `--dark`. What is left is `--link` (develop against the checkout rather
  than a copy), `--yes`, and `--uninstall`.
- **Only the line we own is rewritten.** `/etc/sddm.conf` keeps everything else
  in it; the greeter's `theme.conf` keeps `message` and `label`.
- Shell-rc additions are guarded on `case $- in *i*)` so `scp`, `rsync` and
  scripted shells never see them.

### `usage()` is an unquoted heredoc

The paths in it are expanded on purpose, which means **backticks and `$(...)`
in that prose are executed**. `./install.sh --help` once launched weston
because the help text contained `` `weston --shell=kiosk` ``.

---

## Verifying changes

- **The greeter**: `./scripts/test-sddm.sh` drives it under QtTest with
  stand-ins for SDDM's five context objects. It cannot see anything the
  compositor does to a real click — synthesised events go straight into the
  window.
- **The shell**: `qs -c brutal log -t N`. ANSI codes sit *between* `qml` and
  `:`, so strip with `sed 's/\x1b\[[0-9;]*m//g'` first. The log is cumulative —
  compare counts before and after a forced reload rather than reading the tail.
  Touching a file does not trigger a reload; the content must change.
- **The whole desktop**: `./scripts/test-nested.sh`.

### Screenshots lie in two specific ways

Both have caught me out; both are arithmetic, not judgement.

- `dim_inactive` is on at `dim_strength 0.5`. An unfocused window captures at
  exactly half brightness — cream `250,240,230` arrives as `125,120,115`.
  Multiplying by 2 recovers it exactly.
- The dashboard scrim is `#B3000000`, so anything behind it captures at 30%.
  `197 × 0.30 = 59.1`.

### Check glyphs against the font, in both weights

This is only auditable because glyphs are named in one file — see *Icons are
named, never spelled*. A codepoint written inline is checked by nobody.

That property is enforceable, so enforce it — this must print nothing:

```sh
grep -rlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' \
  --include='*.qml' .config/quickshell/brutal | grep -v Config/Icons.qml
```

`➤` (U+27A4) is **not** in JetBrainsMono Nerd Font. A missing glyph falls
through to whatever fontconfig picks next, which is rarely cell-width, and that
knocks every pill on the line out of alignment.

### Never `pkill` by name, never auto-detect an instance

Kill only the exact PID captured at launch. Every Hyprland instance of the same
build shares a commit-hash prefix, so scanning `/run/user/1000/hypr` and taking
the newest returns the *live session*. Doing both at once once killed the
user's whole desktop.

---

## House style

- Comments explain **why**, and only where a reader would otherwise be
  surprised. The rationale goes here.
- Prefer measuring to asserting. Contrast ratios, glyph coverage and timing
  numbers in this repo were all computed, not estimated.
- When something cannot be verified, say so rather than implying it was.
