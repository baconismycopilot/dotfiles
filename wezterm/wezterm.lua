-- WezTerm configuration. Works on macOS and Linux; the keybindings use SUPER
-- on macOS and ALT elsewhere, with the same keys on both.
--
-- Reload with CTRL+SHIFT+R (WezTerm's default) after editing.

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

local is_mac = wezterm.target_triple:find("apple") ~= nil
local is_windows = wezterm.target_triple:find("windows") ~= nil
local mod = is_mac and "SUPER" or "ALT"

---------------------------------------------------------------------------
-- Appearance
---------------------------------------------------------------------------

config.color_scheme = "Builtin Pastel Dark"

-- WezTerm bundles JetBrains Mono and Nerd Font Symbols, so this stack works
-- even on a host without either installed.
config.font = wezterm.font_with_fallback({
	"JetBrains Mono",
	{ family = "Symbols Nerd Font Mono", scale = 0.8 },
})
config.font_size = 10.5
config.use_cap_height_to_scale_fallback_fonts = true

config.hide_tab_bar_if_only_one_tab = true
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
-- Keys
---------------------------------------------------------------------------

config.keys = {
	-- Panes: mod+d splits side by side, mod+shift+d stacks.
	{ key = "d", mods = mod, action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = mod .. "|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

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
