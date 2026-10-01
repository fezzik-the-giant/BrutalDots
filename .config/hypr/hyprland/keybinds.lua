-- Keybindings.
--
-- SUPER is the modifier throughout. Shell surfaces use Hyprland's `global`
-- dispatcher, wired to the GlobalShortcut declarations in shell.qml; the same
-- actions are reachable over IPC, e.g.
--     hl.dsp.exec_cmd("qs -c brutal ipc call shell dashboard")
--
-- Every bind is declared as data below and registered in one pass at the end.
-- That is what lets the dashboard's Keybinds tab work: it reads the catalogue
-- this file exports and writes overrides back, so a rebind made in the UI and a
-- default changed here cannot drift apart. Editing this file by hand still
-- works exactly as before — change a `key`, not an `hl.bind` call.

local state_dir = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state"))
    .. "/brutaldots"

local CATALOGUE = state_dir .. "/keybinds-catalogue.json"
local OVERRIDES = CONFIG_DIR .. "/custom/keybinds.lua"

-- ── Overrides ───────────────────────────────────────────────────────────────
-- Your changes live in custom/keybinds.lua, inside a block the dashboard's
-- Keybinds tab owns. That file is loaded normally later on, so anything you
-- write around the block keeps working exactly as it always has.
--
-- The block is read here as *text*, before any bind is registered, so an
-- override replaces its default rather than being bound alongside it — there is
-- nothing to unbind. Reading rather than executing is also what keeps a
-- half-written file from taking the config down: the worst case is that the
-- block does not match and every default stands.
--
-- An empty value means "bound to nothing".
local OVERRIDE_BEGIN = ">>> BrutalDots keybinds"
local OVERRIDE_END   = "<<< BrutalDots keybinds"

local function read_overrides()
    local f = io.open(OVERRIDES, "r")
    if not f then return {} end
    local text = f:read("*a")
    f:close()

    local block = text:match(OVERRIDE_BEGIN .. "(.-)" .. OVERRIDE_END)
    if not block then return {} end

    local out = {}
    for id, combo in block:gmatch('%[%s*"([%w%.%-_]+)"%s*%]%s*=%s*"([^"]*)"') do
        out[id] = combo
    end
    return out
end

local overrides = read_overrides()

-- ── The catalogue ───────────────────────────────────────────────────────────
-- id       stable name the shell stores an override against; never reuse one
-- group    heading in the Keybinds tab
-- key      the default combo
-- fixed    true for binds the UI must not offer to rebind (the mouse drags)
local binds = {}

local function add(entry)
    binds[#binds + 1] = entry
end

-- ── Shell surfaces ──────────────────────────────────────────────────────────
add({ id = "shell.dashboard",  group = "Shell", key = "SUPER + D",
      description = "Toggle dashboard",     action = hl.dsp.global("brutaldots:dashboard") })
add({ id = "shell.widgets",    group = "Shell", key = "SUPER + W",
      description = "Toggle widgets",       action = hl.dsp.global("brutaldots:widgets") })
add({ id = "shell.power",      group = "Shell", key = "SUPER + Escape",
      description = "Power menu",           action = hl.dsp.global("brutaldots:power") })
add({ id = "shell.launcher",   group = "Shell", key = "SUPER + Space",
      description = "Application launcher", action = hl.dsp.global("brutaldots:launcher") })
add({ id = "shell.clipboard",  group = "Shell", key = "SUPER + V",
      description = "Clipboard history",    action = hl.dsp.global("brutaldots:clipboard") })
add({ id = "shell.wallpaper",  group = "Shell", key = "SUPER + SHIFT + W",
      description = "Wallpaper picker",     action = hl.dsp.global("brutaldots:wallpaper") })

-- SUPER + L is taken by the vim-style "focus right" bind below, so the lock
-- lives one modifier away rather than fighting it.
add({ id = "shell.lock",       group = "Shell", key = "SUPER + ALT + L",
      description = "Lock session",         action = hl.dsp.global("brutaldots:lock") })

add({ id = "shell.keepAwake",  group = "Shell", key = "SUPER + SHIFT + I",
      description = "Toggle keep-awake",    action = hl.dsp.global("brutaldots:keepAwake") })
add({ id = "shell.nightLight", group = "Shell", key = "SUPER + SHIFT + N",
      description = "Toggle night light",   action = hl.dsp.global("brutaldots:nightLight") })
add({ id = "shell.darkMode",   group = "Shell", key = "SUPER + SHIFT + T",
      description = "Toggle dark mode",     action = hl.dsp.global("brutaldots:darkMode") })
add({ id = "shell.restart",    group = "Shell", key = "CTRL + SUPER + R",
      description = "Restart the shell",
      action = hl.dsp.exec_cmd("killall qs; qs -c brutal &") })

-- ── Applications ────────────────────────────────────────────────────────────
add({ id = "launch.terminal", group = "Launch", key = "SUPER + Return",
      description = "Terminal", action = hl.dsp.global("brutaldots:launchTerminal") })
add({ id = "launch.browser",  group = "Launch", key = "SUPER + B",
      description = "Browser",  action = hl.dsp.global("brutaldots:launchBrowser") })
add({ id = "launch.files",    group = "Launch", key = "SUPER + E",
      description = "Files",    action = hl.dsp.global("brutaldots:launchFiles") })

-- ── Windows ─────────────────────────────────────────────────────────────────
add({ id = "window.close",      group = "Window", key = "SUPER + Q",
      description = "Close",      action = hl.dsp.window.close() })
add({ id = "window.fullscreen", group = "Window", key = "SUPER + F",
      description = "Fullscreen",
      action = hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }) })
add({ id = "window.maximise",   group = "Window", key = "SUPER + M",
      description = "Maximise",
      action = hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }) })
add({ id = "window.float",      group = "Window", key = "SUPER + ALT + Space",
      description = "Float / tile",
      action = hl.dsp.window.float({ action = "toggle" }) })
add({ id = "window.pin",        group = "Window", key = "SUPER + P",
      description = "Pin",        action = hl.dsp.window.pin() })

-- Mouse drags. Fixed: the capture UI listens for a key combo, and there is no
-- sensible way to press mouse:272 into it.
add({ id = "window.drag",   group = "Window", key = "SUPER + mouse:272", fixed = true,
      description = "Move with the mouse",   action = hl.dsp.window.drag(),   mouse = true })
add({ id = "window.resize", group = "Window", key = "SUPER + mouse:273", fixed = true,
      description = "Resize with the mouse", action = hl.dsp.window.resize(), mouse = true })

-- Focus and move, by arrow key and by vim keys. Both sets are listed so the
-- Keybinds tab can show — and rebind — either one.
local dirs   = { "l", "r", "u", "d" }
local arrows = { "Left", "Right", "Up", "Down" }
local vim    = { "H", "L", "K", "J" }
local names  = { "left", "right", "up", "down" }

for i = 1, 4 do
    add({ id = "window.focus." .. names[i], group = "Window",
          key = "SUPER + " .. arrows[i],
          description = "Focus " .. names[i],
          action = hl.dsp.focus({ direction = dirs[i] }) })
    add({ id = "window.focus.vim." .. names[i], group = "Window",
          key = "SUPER + " .. vim[i],
          description = "Focus " .. names[i] .. " (vim)",
          action = hl.dsp.focus({ direction = dirs[i] }) })

    add({ id = "window.move." .. names[i], group = "Window",
          key = "SUPER + SHIFT + " .. arrows[i],
          description = "Move " .. names[i],
          action = hl.dsp.window.move({ direction = dirs[i] }) })
    add({ id = "window.move.vim." .. names[i], group = "Window",
          key = "SUPER + SHIFT + " .. vim[i],
          description = "Move " .. names[i] .. " (vim)",
          action = hl.dsp.window.move({ direction = dirs[i] }) })
end

-- ── Workspaces ──────────────────────────────────────────────────────────────
for i = 1, 10 do
    local key = (i == 10) and 0 or i
    add({ id = "workspace.focus." .. i, group = "Workspace",
          key = "SUPER + " .. key,
          description = "Focus workspace " .. i,
          action = hl.dsp.focus({ workspace = i }) })
    add({ id = "workspace.send." .. i, group = "Workspace",
          key = "SUPER + SHIFT + " .. key,
          description = "Send window to workspace " .. i,
          action = hl.dsp.window.move({ workspace = i, follow = false }) })
end

add({ id = "workspace.prev", group = "Workspace", key = "CTRL + SUPER + Left",
      description = "Focus workspace left",
      action = hl.dsp.focus({ workspace = "r-1" }) })
add({ id = "workspace.next", group = "Workspace", key = "CTRL + SUPER + Right",
      description = "Focus workspace right",
      action = hl.dsp.focus({ workspace = "r+1" }) })

add({ id = "workspace.scratchpad", group = "Workspace", key = "SUPER + S",
      description = "Toggle scratchpad",
      action = hl.dsp.workspace.toggle_special("special") })
add({ id = "workspace.sendScratchpad", group = "Workspace", key = "SUPER + SHIFT + S",
      description = "Send window to scratchpad",
      action = hl.dsp.window.move({ workspace = "special:special", follow = false }) })

-- ── Media and hardware keys ─────────────────────────────────────────────────
-- `locked` keeps these working while the session is locked; `repeating` lets
-- volume and brightness ramp while the key is held.
add({ id = "media.playPause", group = "Media", key = "XF86AudioPlay",
      description = "Play / pause",
      action = hl.dsp.exec_cmd("playerctl play-pause"), locked = true })
add({ id = "media.playPauseAlt", group = "Media", key = "XF86AudioPause",
      description = "Play / pause (pause key)",
      action = hl.dsp.exec_cmd("playerctl play-pause"), locked = true })
add({ id = "media.next", group = "Media", key = "XF86AudioNext",
      description = "Next track",
      action = hl.dsp.exec_cmd("playerctl next"), locked = true })
add({ id = "media.previous", group = "Media", key = "XF86AudioPrev",
      description = "Previous track",
      action = hl.dsp.exec_cmd("playerctl previous"), locked = true })

add({ id = "media.volumeUp", group = "Media", key = "XF86AudioRaiseVolume",
      description = "Volume up",
      action = hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
      locked = true, repeating = true })
add({ id = "media.volumeDown", group = "Media", key = "XF86AudioLowerVolume",
      description = "Volume down",
      action = hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
      locked = true, repeating = true })
add({ id = "media.mute", group = "Media", key = "XF86AudioMute",
      description = "Mute output",
      action = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
      locked = true })
add({ id = "media.micMute", group = "Media", key = "XF86AudioMicMute",
      description = "Mute microphone",
      action = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
      locked = true })

add({ id = "media.brightnessUp", group = "Media", key = "XF86MonBrightnessUp",
      description = "Brightness up",
      action = hl.dsp.exec_cmd("brightnessctl set 5%+"),
      locked = true, repeating = true })
add({ id = "media.brightnessDown", group = "Media", key = "XF86MonBrightnessDown",
      description = "Brightness down",
      action = hl.dsp.exec_cmd("brightnessctl set 5%-"),
      locked = true, repeating = true })

-- ── Screenshots, recording, colour ──────────────────────────────────────────
-- These go through the shell rather than calling grim directly, so every shot
-- lands in the same directory, is copied to the clipboard, and can be sent to
-- an annotation tool by flipping `capture.annotate` in settings.json.
add({ id = "capture.regionPrint", group = "Capture", key = "Print",
      description = "Screenshot a region",
      action = hl.dsp.global("brutaldots:screenshotRegion") })
add({ id = "capture.screen", group = "Capture", key = "SHIFT + Print",
      description = "Screenshot the screen",
      action = hl.dsp.global("brutaldots:screenshotScreen") })
add({ id = "capture.window", group = "Capture", key = "ALT + Print",
      description = "Screenshot the active window",
      action = hl.dsp.global("brutaldots:screenshotWindow") })
add({ id = "capture.region", group = "Capture", key = "SUPER + SHIFT + C",
      description = "Screenshot a region",
      action = hl.dsp.global("brutaldots:screenshotRegion") })

add({ id = "capture.recordRegion", group = "Capture", key = "SUPER + SHIFT + R",
      description = "Record a region (press again to stop)",
      action = hl.dsp.global("brutaldots:recordRegion") })
add({ id = "capture.recordScreen", group = "Capture", key = "SUPER + ALT + R",
      description = "Record the screen (press again to stop)",
      action = hl.dsp.global("brutaldots:recordScreen") })

add({ id = "capture.colour", group = "Capture", key = "SUPER + SHIFT + P",
      description = "Pick a colour",
      action = hl.dsp.global("brutaldots:pickColour") })

-- ── Registration ────────────────────────────────────────────────────────────
for _, b in ipairs(binds) do
    local combo = overrides[b.id]
    if combo == nil then combo = b.key end

    -- An override set to the empty string means the user cleared the bind.
    if combo ~= "" then
        hl.bind(combo, b.action, {
            description = b.group .. ": " .. b.description,
            mouse = b.mouse,
            locked = b.locked,
            repeating = b.repeating
        })
    end
end

-- ── Rebind capture ──────────────────────────────────────────────────────────
-- A submap holding nothing but an escape hatch. The Keybinds tab switches into
-- it while it is listening for a new combo, which makes every other bind inert
-- for the duration — otherwise pressing SUPER + Q to assign it would close the
-- window behind the dashboard instead of being captured.
--
-- Escape resets it here rather than in the shell so that a shell that dies
-- mid-capture cannot leave the session with no working binds at all.
hl.define_submap("brutaldots_capture", function()
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

-- ── Catalogue export ────────────────────────────────────────────────────────
-- What the Keybinds tab reads: the id, where it belongs, what it does, and the
-- default it can be reset to. Written on every config load, so it follows edits
-- to this file without the shell needing to parse Lua.
local function json_escape(s)
    return (tostring(s):gsub('[\\"]', "\\%0"):gsub("\n", "\\n"))
end

local function export_catalogue()
    os.execute(string.format("mkdir -p %q", state_dir))

    -- Written to a sibling and renamed into place: the shell watches this file
    -- and would otherwise read it while it is still half-written, every time
    -- the config reloads.
    local tmp = CATALOGUE .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end

    local parts = {}
    for _, b in ipairs(binds) do
        parts[#parts + 1] = string.format(
            '{"id":"%s","group":"%s","description":"%s","default":"%s","fixed":%s}',
            json_escape(b.id), json_escape(b.group), json_escape(b.description),
            json_escape(b.key), b.fixed and "true" or "false")
    end

    f:write("[", table.concat(parts, ",\n "), "]\n")
    f:close()
    os.rename(tmp, CATALOGUE)
end

export_catalogue()
