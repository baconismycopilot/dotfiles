-- WezTerm configuration, shared by macOS and Linux. install.sh symlinks it to
-- $XDG_CONFIG_HOME/wezterm/wezterm.lua and WezTerm reloads it on save.
--
-- Window-level chords use SUPER on macOS and ALT elsewhere, with the same keys
-- on both. Pane management goes through a tmux-style leader (CTRL+a, then a
-- key) so it never collides with shell or editor bindings.
--
-- Docs: https://wezterm.org/config/lua/config/

local wezterm = require("wezterm")
local act = wezterm.action

-- config_builder validates option names and types as they are assigned, so a
-- typo shows up in the GUI's warning window instead of being silently ignored.
local config = wezterm.config_builder()

-- OS detection. wezterm.target_triple is the Rust build target:
--   x86_64-apple-darwin / aarch64-apple-darwin  macOS
--   x86_64-unknown-linux-gnu                     Linux
local is_mac = wezterm.target_triple:find("apple") ~= nil
local is_windows = wezterm.target_triple:find("windows") ~= nil
local mod = is_mac and "SUPER" or "ALT"

---------------------------------------------------------------------------
-- Appearance
---------------------------------------------------------------------------

-- Built in; browse alternatives at https://wezterm.org/colorschemes/
config.color_scheme = "Builtin Pastel Dark"

-- WezTerm bundles JetBrains Mono and Nerd Font Symbols, so this stack works
-- even on a host without either installed.
config.font = wezterm.font_with_fallback({
	"JetBrains Mono",
	{ family = "Symbols Nerd Font Mono", scale = 0.8 },
})
config.font_size = is_mac and 13.0 or 10.5 -- macOS renders the same pt size smaller
config.use_cap_height_to_scale_fallback_fonts = true

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_padding = {
	left = "2cell",
	right = "1.5cell",
}

-- Flash instead of beep.
config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_function = "EaseIn",
	fade_in_duration_ms = 75,
	fade_out_function = "EaseOut",
	fade_out_duration_ms = 75,
}
config.colors = {
	visual_bell = "#fee000",
}

---------------------------------------------------------------------------
-- Behavior
---------------------------------------------------------------------------

config.scrollback_lines = 20000

-- Inline graphics (mcat, yazi, tdf). WezTerm supports iTerm2, Sixel and Kitty
-- image protocols and enables all three by default in current releases. Kept
-- explicit so the intent is documented and older builds behave the same.
config.enable_kitty_graphics = true

if is_mac then
	-- Left Option acts as Alt (Meta) for shell and editor bindings instead of
	-- composing symbols. This is WezTerm's default; stated here so it is obvious.
	-- Right Option still composes (Right-Opt n, then n = ñ), like AltGr.
	config.send_composed_key_when_left_alt_is_pressed = false
end

if is_windows then
	-- Start straight into WSL on Windows.
	-- config.default_prog = { "wsl.exe", "--cd", "~" }
end

---------------------------------------------------------------------------
-- Toggles bound below. Both flip a config override on the current window.
---------------------------------------------------------------------------

wezterm.on("toggle-ligature", function(window)
	local overrides = window:get_config_overrides() or {}
	if overrides.harfbuzz_features then
		overrides.harfbuzz_features = nil
	else
		overrides.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
	end
	window:set_config_overrides(overrides)
end)

wezterm.on("toggle-opacity", function(window)
	local overrides = window:get_config_overrides() or {}
	if overrides.window_background_opacity then
		overrides.window_background_opacity = nil
	else
		overrides.window_background_opacity = 0.9
	end
	window:set_config_overrides(overrides)
end)

---------------------------------------------------------------------------
-- Keys. WezTerm's default bindings stay active alongside these.
---------------------------------------------------------------------------

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
	-- Panes: mod+d splits side by side, mod+shift+d stacks.
	-- Same splits via the leader: leader then | (side by side) or - (stacked).
	{ key = "d", mods = mod, action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = mod .. "|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- Pane navigation: leader then h/j/k/l; leader then z zooms the pane.
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },

	-- Tabs: mod+t new, mod+w close pane (asks first), mod+[ / mod+] switch.
	{ key = "t", mods = mod, action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "w", mods = mod, action = act.CloseCurrentPane({ confirm = true }) },
	{ key = "[", mods = mod, action = act.ActivateTabRelative(-1) },
	{ key = "]", mods = mod, action = act.ActivateTabRelative(1) },

	-- Send a literal CTRL+a through to the shell (press CTRL+a twice).
	{ key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },

	{ key = "Return", mods = mod, action = act.ToggleFullScreen },

	-- Clear scrollback and the screen, then redraw the prompt.
	{
		key = "k",
		mods = mod,
		action = act.Multiple({
			act.ClearScrollback("ScrollbackAndViewport"),
			act.SendKey({ key = "L", mods = "CTRL" }),
		}),
	},

	{ key = "u", mods = mod, action = act.EmitEvent("toggle-opacity") },
	{ key = "L", mods = "CTRL", action = act.EmitEvent("toggle-ligature") },

	-- Swallow F13 (the key some keyboards put where Print Screen was).
	{ key = "F13", action = act.Nop },

	-- Ctrl+Backspace deletes the previous word, like Ctrl+W.
	{ key = "Backspace", mods = "CTRL", action = act.SendKey({ key = "w", mods = "CTRL" }) },
}

return config
