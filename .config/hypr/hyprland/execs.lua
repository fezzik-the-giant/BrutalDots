-- Startup commands.
--
-- Everything here is conditional: a missing tool is skipped rather than failing,
-- so this config still comes up on a minimal system. Your own autostarts belong
-- in custom/execs.lua — hl.on handlers stack, so that file runs alongside this
-- one rather than replacing it.

-- How to launch the shell.
--
-- BRUTALDOTS_SHELL_CMD wins, which is how scripts/test-nested.sh points a
-- nested session at a checkout. Otherwise: an installed shell is launched by
-- name, and a config being run straight out of a checkout — a second session
-- entry pointing at <repo>/hypr/hyprland.lua — launches the shell sitting
-- beside it, so the whole desktop works with nothing installed.
local function detect_shell_cmd()
    local override = os.getenv("BRUTALDOTS_SHELL_CMD")
    if override then return override end

    local config_home = os.getenv("XDG_CONFIG_HOME") or (HOME .. "/.config")
    if is_file_exists(config_home .. "/quickshell/brutal/shell.qml") then
        return "qs -c brutal"
    end

    local beside = CONFIG_DIR .. "/../quickshell/brutal"
    if is_file_exists(beside .. "/shell.qml") then
        return string.format("qs -p %q", beside)
    end

    -- Nothing found. Launch by name anyway so the failure shows up in the log
    -- as a missing config rather than as silence.
    return "qs -c brutal"
end

local shell_cmd = detect_shell_cmd()
-- Global so keybinds.lua, loaded after this, reaches the same shell — under
-- test-nested.sh, `qs -c brutal` would be the live session's.
SHELL_IPC = shell_cmd .. " ipc call shell"
local shell_ipc = SHELL_IPC

-- Cursor theme and size. Override in custom/env.lua.
local cursor_theme = os.getenv("XCURSOR_THEME") or "Adwaita"
local cursor_size  = os.getenv("XCURSOR_SIZE") or "24"

hl.on("hyprland.start", function()
    -- ── The shell ───────────────────────────────────────────────────────────
    -- The shell also provides the polkit agent, the notification daemon, the
    -- lock screen and idle handling, so none of those need a separate process.
    hl.exec_cmd(shell_cmd)

    -- ── Session plumbing ────────────────────────────────────────────────────
    -- Export the Wayland session to D-Bus and systemd, so xdg-desktop-portal
    -- can do screen sharing and file pickers. Without this, screen sharing
    -- silently produces a black frame.
    hl.exec_cmd("dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")

    -- Secret storage, for apps that expect a keyring.
    hl.exec_cmd("command -v gnome-keyring-daemon >/dev/null && " ..
        "gnome-keyring-daemon --start --components=secrets")

    -- ── Clipboard history ───────────────────────────────────────────────────
    -- Fills the store the SUPER+V picker reads. Text and images are watched
    -- separately because wl-paste can only follow one MIME class at a time.
    hl.exec_cmd("command -v cliphist >/dev/null || exit 0; " ..
        "wl-paste --type text --watch cliphist store")
    hl.exec_cmd("command -v cliphist >/dev/null || exit 0; " ..
        "wl-paste --type image --watch cliphist store")

    -- ── Lock on request and before sleep ────────────────────────────────────
    -- `loginctl lock-session` and suspend both announce themselves on the
    -- system bus. gdbus (from glib2, always present) can subscribe as a normal
    -- user, which dbus-monitor cannot, so this needs no privileges.
    hl.exec_cmd("command -v gdbus >/dev/null || exit 0; " ..
        "gdbus monitor --system --dest org.freedesktop.login1 | " ..
        "while read -r line; do case \"$line\" in " ..
        "*\".Session.Lock ()\"*|*\"PrepareForSleep (true,)\"*) " ..
        shell_ipc .. " lock >/dev/null 2>&1 ;; esac; done")

    -- ── Appearance ──────────────────────────────────────────────────────────
    hl.exec_cmd(string.format(
        "[ -d /usr/share/icons/%s ] && hyprctl setcursor %s %s",
        cursor_theme, cursor_theme, cursor_size))

    -- Colour temperature daemon. Started idle at 6000K; the shell's night
    -- light toggle drives it over hyprctl.
    hl.exec_cmd("command -v hyprsunset >/dev/null || exit 0; " ..
        "pgrep -x hyprsunset >/dev/null || exec hyprsunset")

    -- No wallpaper daemon is started: the shell draws the background itself,
    -- on a layer-shell surface it already owns. Pick an image with
    -- SUPER+SHIFT+W, or set wallpaper.enabled to false and start swww or
    -- hyprpaper from custom/execs.lua instead.
end)
