-- keymap.lua: a small WezTerm plugin for seeing and choosing key bindings.
--
-- What it adds (all opt-out via `opts`):
--   * Leader hints: while the leader is active (or a key table is), the right
--     side of the tab bar lists the chords that are available next.
--   * A keymap menu on <leader> ? with fuzzy-searchable lists:
--       Bindings         every active chord, built-in and custom; Enter runs it
--       Chord audit      free / taken chords per modifier; Enter copies a
--                        ready-to-paste `{ key = ..., mods = ..., action = ... }`
--       System shortcuts what the desktop (KDE Plasma, macOS) grabs before
--                        WezTerm sees the key, plus the CTRL/ALT chords the shell
--                        itself uses
--       Actions          KeyAssignment reference; Enter opens the docs page
--       Full report      all of the above as text in a new tab
--   * Load-time warnings (wezterm.log_warn, see the debug overlay) for custom
--     bindings that a desktop shortcut shadows.
--
-- Data comes from WezTerm itself (wezterm.gui.default_keys(), the effective
-- config) and from the desktop (KDE: ~/.config/kglobalshortcutsrc; macOS: the
-- documented system defaults), so nothing here goes stale when wezterm.lua
-- changes.
--
-- Usage, in wezterm.lua:
--   local keymap = require("keymap")
--   keymap.apply_to_config(config, { menu_key = { key = "?", mods = "LEADER|SHIFT" } })
--
-- Laid out like a wezterm.plugin module (apply_to_config) so it could be moved
-- to its own repo and loaded with wezterm.plugin.require later.

local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

local DEFAULTS = {
	menu_key = { key = "?", mods = "LEADER|SHIFT" },
	leader_hints = true, -- show available chords in the right status while LEADER is held
	warn_on_load = true, -- wezterm.log_warn for custom chords a desktop shortcut shadows
	report_path = nil, -- defaults to $XDG_CACHE_HOME/wezterm/keymap.txt
}

local is_mac = wezterm.target_triple:find("apple") ~= nil

---------------------------------------------------------------------------
-- Chord normalisation. "mapped:L" + CTRL and "l" + SHIFT|CTRL are the same
-- chord; KDE writes letters upper-case; modifier order varies by source.
---------------------------------------------------------------------------

local MOD_ORDER = { LEADER = 1, SUPER = 2, CTRL = 3, ALT = 4, SHIFT = 5 }
local KEY_NAMES = { ["\27"] = "Escape", ["\r"] = "Enter", ["\n"] = "Enter", ["\t"] = "Tab", [" "] = "Space", ["\8"] = "Backspace", ["\127"] = "Delete" }
local KEY_ALIASES = { Return = "Enter" }

local function norm(key, mods)
	key = key:gsub("^mapped:", ""):gsub("^phys:", "")
	key = KEY_NAMES[key] or KEY_ALIASES[key] or key
	local set = {}
	for m in (mods or "NONE"):gmatch("[^|]+") do
		if m ~= "NONE" then
			set[m] = true
		end
	end
	if #key == 1 and key:match("%a") then
		if key:match("%u") then
			set.SHIFT = true
		end
		key = key:lower()
	end
	local list = {}
	for m in pairs(set) do
		list[#list + 1] = m
	end
	table.sort(list, function(a, b)
		return (MOD_ORDER[a] or 9) < (MOD_ORDER[b] or 9)
	end)
	return key, table.concat(list, "|")
end

local function chord(key, mods)
	return mods ~= "" and (mods .. "+" .. key) or key
end

local function chord_id(key, mods)
	return mods .. "\0" .. key
end

---------------------------------------------------------------------------
-- Action descriptions. Actions are plain strings ("Hide") or one-key tables
-- ({ SplitHorizontal = { domain = "CurrentPaneDomain" } }).
---------------------------------------------------------------------------

local function compact(v, depth)
	depth = depth or 0
	local t = type(v)
	if t ~= "table" then
		return tostring(v)
	end
	if depth > 3 then
		return "…"
	end
	local parts = {}
	if #v > 0 then
		for _, item in ipairs(v) do
			parts[#parts + 1] = M.describe(item, depth + 1)
		end
		return table.concat(parts, ", ")
	end
	local keys = {}
	for k in pairs(v) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, k in ipairs(keys) do
		local val = v[k]
		local skip = (k == "set_environment_variables" and type(val) == "table" and next(val) == nil)
			or (k == "domain" and val == "CurrentPaneDomain")
		if not skip then
			parts[#parts + 1] = tostring(k) .. "=" .. compact(val, depth + 1)
		end
	end
	if #parts == 0 then
		return ""
	end
	return "{" .. table.concat(parts, " ") .. "}"
end

--- One-line, human-sized description of a KeyAssignment.
function M.describe(action, depth)
	if type(action) == "string" then
		return action
	end
	if type(action) ~= "table" then
		return tostring(action)
	end
	local name, arg = next(action)
	if name == nil then
		return "{}"
	end
	if name == "Multiple" and type(arg) == "table" then
		local parts = {}
		for _, a in ipairs(arg) do
			parts[#parts + 1] = M.describe(a, (depth or 0) + 1)
		end
		return "Multiple(" .. table.concat(parts, "; ") .. ")"
	end
	if arg == true or arg == nil then
		return name
	end
	local rest = compact(arg, depth)
	return rest ~= "" and (name .. " " .. rest) or name
end

---------------------------------------------------------------------------
-- Effective bindings: WezTerm defaults overlaid by config.keys.
---------------------------------------------------------------------------

--- Returns an ordered list of { key, mods, chord, action, desc, source } where
--- source is "default", "config" or "override" (config replaced a default).
function M.bindings(config)
	local by_id, order = {}, {}
	local function add(entry, source)
		local key, mods = norm(entry.key, entry.mods)
		local id = chord_id(key, mods)
		local existing = by_id[id]
		local desc = M.describe(entry.action)
		if existing then
			if existing.desc ~= desc then
				existing.source = "override"
				existing.overrides = existing.desc
			end
			existing.action, existing.desc = entry.action, desc
		else
			local e = { key = key, mods = mods, chord = chord(key, mods), action = entry.action, desc = desc, source = source }
			by_id[id] = e
			order[#order + 1] = e
		end
	end
	if wezterm.gui and not config.disable_default_key_bindings then
		for _, e in ipairs(wezterm.gui.default_keys()) do
			add(e, "default")
		end
	end
	for _, e in ipairs(config.keys or {}) do
		add(e, "config")
	end
	table.sort(order, function(a, b)
		local am, bm = select(2, a.mods:gsub("|", "")), select(2, b.mods:gsub("|", ""))
		if am ~= bm then
			return am < bm
		end
		if a.mods ~= b.mods then
			return a.mods < b.mods
		end
		if (#a.key > 1) ~= (#b.key > 1) then
			return #a.key == 1
		end
		return a.key:lower() < b.key:lower()
	end)
	return order, by_id
end

---------------------------------------------------------------------------
-- Desktop / OS global shortcuts and shell chords.
---------------------------------------------------------------------------

-- Apple's documented system-wide defaults (Cmd = SUPER, Option = ALT).
local MACOS_SYSTEM = {
	{ "SUPER", "Space", "Spotlight" },
	{ "SUPER", "Tab", "Switch application" },
	{ "SUPER", "`", "Switch window of current app" },
	{ "SUPER", "q", "Quit app" },
	{ "SUPER", "h", "Hide app" },
	{ "SUPER|ALT", "h", "Hide other apps" },
	{ "SUPER", "m", "Minimize window" },
	{ "SUPER|ALT", "m", "Minimize all windows of app" },
	{ "SUPER|ALT", "Escape", "Force Quit" },
	{ "SUPER|ALT", "d", "Show/hide Dock" },
	{ "SUPER|SHIFT", "3", "Screenshot: screen" },
	{ "SUPER|SHIFT", "4", "Screenshot: area" },
	{ "SUPER|SHIFT", "5", "Screenshot / recording" },
	{ "SUPER|SHIFT", "q", "Log out" },
	{ "SUPER|CTRL", "q", "Lock screen" },
	{ "SUPER|CTRL", "Space", "Emoji & Symbols" },
	{ "SUPER|CTRL", "f", "Toggle full screen (app)" },
	{ "SUPER|CTRL", "d", "Look up word" },
	{ "CTRL", "UpArrow", "Mission Control" },
	{ "CTRL", "DownArrow", "Application windows" },
	{ "CTRL", "LeftArrow", "Previous Space" },
	{ "CTRL", "RightArrow", "Next Space" },
	{ "CTRL", "Space", "Next input source" },
	{ "CTRL|ALT", "Space", "Previous input source" },
	{ "CTRL", "F2", "Focus menu bar" },
	{ "CTRL", "F3", "Focus Dock" },
	{ "SUPER|ALT|CTRL", "8", "Invert colors (if enabled)" },
	{ "ALT", "Space", "Finder search (configurable)" },
	{ "SUPER|ALT", "Space", "Finder search window" },
}

-- Chords the shell (readline / zsh zle) or the tty consumes. Binding them in
-- WezTerm takes them away from the shell, so they are not reported as free.
local SHELL = {
	CTRL = {
		a = "beginning-of-line", b = "backward-char", c = "SIGINT", d = "EOF / delete-char",
		e = "end-of-line", f = "forward-char", g = "abort", h = "backspace", i = "tab",
		j = "newline", k = "kill-line", l = "clear-screen", m = "enter", n = "down-history",
		o = "accept-line-and-down", p = "up-history", q = "XON (flow control)",
		r = "history-search", s = "XOFF (flow control)", t = "transpose-chars",
		u = "kill-whole-line", v = "quoted-insert", w = "backward-kill-word",
		x = "prefix (C-x ...)", y = "yank", z = "SIGTSTP", ["["] = "escape", ["_"] = "undo",
		["/"] = "undo",
	},
	ALT = {
		b = "backward-word", f = "forward-word", d = "kill-word", ["."] = "insert-last-word",
		u = "upcase-word", l = "downcase-word", c = "capitalize-word", t = "transpose-words",
		y = "yank-pop", ["<"] = "beginning-of-history", [">"] = "end-of-history",
		Backspace = "backward-kill-word", ["?"] = "list completions", ["*"] = "insert completions",
	},
}

local KDE_MODS = { Meta = "SUPER", Ctrl = "CTRL", Alt = "ALT", Shift = "SHIFT" }
local KDE_KEYS = {
	Left = "LeftArrow", Right = "RightArrow", Up = "UpArrow", Down = "DownArrow",
	PgUp = "PageUp", PgDown = "PageDown", Esc = "Escape", Del = "Delete", Ins = "Insert",
	Return = "Enter", Backtab = "Tab",
}

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("a")
	f:close()
	return s
end

local function kde_combo(combo)
	local tokens = {}
	local key
	if combo:sub(-2) == "++" then
		combo, key = combo:sub(1, -3), "+"
	end
	for t in combo:gmatch("[^+]+") do
		tokens[#tokens + 1] = t
	end
	if not key then
		key = table.remove(tokens)
	end
	if not key then
		return nil
	end
	local mods = {}
	for _, t in ipairs(tokens) do
		if not KDE_MODS[t] then
			return nil
		end
		mods[#mods + 1] = KDE_MODS[t]
	end
	key = KDE_KEYS[key] or key
	if not (key:match("^F%d+$") or key:match("^%a+$") or utf8.len(key) == 1) then
		return nil -- media keys and the like
	end
	if #key == 1 then
		key = key:lower() -- KDE writes Meta+A for Meta+a; Shift is always explicit
	end
	return norm(key, table.concat(mods, "|"))
end

local function kde_shortcuts()
	local xdg = os.getenv("XDG_CONFIG_HOME") or (wezterm.home_dir .. "/.config")
	local text = read_file(xdg .. "/kglobalshortcutsrc")
	if not text then
		return {}
	end
	local out, section, friendly = {}, nil, nil
	for line in text:gmatch("[^\r\n]+") do
		local sec = line:match("^%[(.-)%]$")
		if sec then
			section, friendly = sec, sec
		elseif line:match("^_k_friendly_name=") then
			friendly = line:match("^_k_friendly_name=(.*)$")
		else
			local name, value = line:match("^([^=]+)=(.*)$")
			if name and value then
				local active, _, desc = value:match("^([^,]*),([^,]*),?(.*)$")
				active = active or ""
				if desc == nil or desc == "" then
					desc = name
				end
				if active ~= "" and active ~= "none" then
					for raw in active:gsub("\\t", "\t"):gmatch("[^\t]+") do
						local combo = raw:match("^%s*(.-)%s*$")
						if KDE_MODS[combo] then
							out[chord_id("<alone>", KDE_MODS[combo])] = { chord = KDE_MODS[combo] .. " (alone)", desc = desc .. " (" .. friendly .. ")" }
						elseif combo ~= "" and combo ~= "none" and combo:find("+", 1, true) then
							local key, mods = kde_combo(combo)
							if key then
								out[chord_id(key, mods)] = { chord = chord(key, mods), desc = desc .. " (" .. friendly .. ")" }
							end
						end
					end
				end
			end
		end
	end
	return out
end

--- Returns label, { [id] = { chord, desc } } for the desktop this host runs.
function M.system_shortcuts()
	if is_mac then
		local out = {}
		for _, row in ipairs(MACOS_SYSTEM) do
			local key, mods = norm(row[2], row[1])
			out[chord_id(key, mods)] = { chord = chord(key, mods), desc = row[3] }
		end
		return "macOS", out
	end
	local desktop = os.getenv("XDG_CURRENT_DESKTOP") or ""
	local kde = kde_shortcuts()
	if next(kde) or desktop:find("KDE") then
		return "KDE Plasma", kde
	end
	return (desktop ~= "" and desktop or "desktop"), {}
end

--- Returns { [id] = { chord, desc } } for shell/tty chords.
function M.shell_shortcuts()
	local out = {}
	for mod, keys in pairs(SHELL) do
		for k, desc in pairs(keys) do
			local key, mods = norm(k, mod)
			out[chord_id(key, mods)] = { chord = chord(key, mods), desc = desc }
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Chord audit: which chords are free.
---------------------------------------------------------------------------

local GRID_KEYS = {}
for c in ("abcdefghijklmnopqrstuvwxyz0123456789-=[];',./`\\"):gmatch(".") do
	GRID_KEYS[#GRID_KEYS + 1] = c
end
for _, k in ipairs({ "Enter", "Tab", "Space", "Backspace", "Escape", "LeftArrow", "RightArrow", "UpArrow", "DownArrow", "PageUp", "PageDown", "Home", "End", "Insert", "Delete" }) do
	GRID_KEYS[#GRID_KEYS + 1] = k
end
for i = 1, 12 do
	GRID_KEYS[#GRID_KEYS + 1] = "F" .. i
end
local GRID_MODS = { "ALT", "ALT|SHIFT", "CTRL|SHIFT", "CTRL|ALT", "SUPER", "SUPER|SHIFT", "LEADER", "LEADER|SHIFT" }

--- Returns a list of { key, mods, chord, status, desc } for every grid chord.
--- status is "free", "wezterm", "system" or "shell".
function M.audit(config)
	local _, bound = M.bindings(config)
	local _, system = M.system_shortcuts()
	local shell = M.shell_shortcuts()
	local rows = {}
	for _, mods in ipairs(GRID_MODS) do
		for _, k in ipairs(GRID_KEYS) do
			local key, m = norm(k, mods)
			local id = chord_id(key, m)
			local row = { key = key, mods = m, chord = chord(key, m) }
			if bound[id] then
				row.status, row.desc = "wezterm", bound[id].desc
			elseif system[id] then
				row.status, row.desc = "system", system[id].desc
			elseif shell[id] then
				row.status, row.desc = "shell", shell[id].desc
			else
				row.status, row.desc = "free", ""
			end
			rows[#rows + 1] = row
		end
	end
	return rows
end

---------------------------------------------------------------------------
-- KeyAssignment reference.
---------------------------------------------------------------------------

local ACTIONS_DOC = "https://wezterm.org/config/lua/keyassignment/"
local ACTIONS = {
	{ "Panes", { "SplitHorizontal", "SplitVertical", "SplitPane", "ActivatePaneDirection", "ActivatePaneByIndex", "AdjustPaneSize", "TogglePaneZoomState", "RotatePanes", "PaneSelect", "CloseCurrentPane", "MovePaneToNewTab" } },
	{ "Tabs", { "SpawnTab", "ActivateTab", "ActivateTabRelative", "ActivateTabRelativeNoWrap", "ActivateLastTab", "MoveTab", "MoveTabRelative", "CloseCurrentTab", "ShowTabNavigator", "SetTabTitle", "ShowLauncher", "ShowLauncherArgs" } },
	{ "Windows", { "SpawnWindow", "SpawnCommandInNewTab", "SpawnCommandInNewWindow", "ToggleFullScreen", "ToggleAlwaysOnTop", "ToggleAlwaysOnBottom", "SetWindowLevel", "Hide", "Show", "HideApplication", "QuitApplication", "StartWindowDrag", "AttachDomain", "DetachDomain", "SwitchToWorkspace", "SwitchWorkspaceRelative" } },
	{ "Clipboard & selection", { "CopyTo", "PasteFrom", "ActivateCopyMode", "CopyMode", "QuickSelect", "QuickSelectArgs", "Search", "SelectTextAtMouseCursor", "ExtendSelectionToMouseCursor", "CompleteSelection", "CompleteSelectionOrOpenLinkAtMouseCursor", "OpenLinkAtMouseCursor", "ClearSelection", "CharSelect" } },
	{ "Scrolling", { "ScrollByLine", "ScrollByPage", "ScrollToTop", "ScrollToBottom", "ScrollToPrompt", "ClearScrollback" } },
	{ "Font", { "IncreaseFontSize", "DecreaseFontSize", "ResetFontSize", "ResetFontAndWindowSize" } },
	{ "Input", { "SendKey", "SendString", "Nop", "DisableDefaultAssignment", "ActivateKeyTable", "PopKeyTable", "ClearKeyTableStack" } },
	{ "Meta", { "ActivateCommandPalette", "ReloadConfiguration", "ShowDebugOverlay", "EmitEvent", "Multiple", "PromptInputLine", "InputSelector", "Confirmation", "OpenUri", "ResetTerminal" } },
}

---------------------------------------------------------------------------
-- Text report.
---------------------------------------------------------------------------

local function pad(s, n)
	local len = utf8.len(s) or #s
	return s .. string.rep(" ", math.max(0, n - len))
end

function M.report(config)
	local out = {}
	local function line(s)
		out[#out + 1] = s or ""
	end
	local label, system = M.system_shortcuts()
	local shell = M.shell_shortcuts()
	local bindings = M.bindings(config)

	line("WezTerm keymap report")
	line(string.rep("=", 21))
	line()
	local leader = config.leader
	line("leader: " .. (leader and chord(norm(leader.key, leader.mods)) .. " (" .. tostring(leader.timeout_milliseconds or 1000) .. "ms)" or "none"))
	line("[cfg] set in wezterm.lua   [cfg overrides default]   [SYS] shadowed by a " .. label .. " shortcut")
	line()
	line("Bindings (default key table)")
	line(string.rep("-", 28))
	local current
	for _, b in ipairs(bindings) do
		if b.mods ~= current then
			current = b.mods
			line()
			line(current ~= "" and current or "(no modifier)")
		end
		local tags = {}
		if b.source == "config" then
			tags[#tags + 1] = "[cfg]"
		elseif b.source == "override" then
			tags[#tags + 1] = "[cfg overrides default: " .. b.overrides .. "]"
		end
		local sys = system[chord_id(b.key, b.mods)]
		if sys then
			tags[#tags + 1] = "[SYS: " .. sys.desc .. "]"
		end
		line("  " .. pad(b.key, 12) .. " " .. pad(b.desc, 60) .. " " .. table.concat(tags, " "))
	end

	for name, table_ in pairs(config.key_tables or {}) do
		line()
		line("Key table: " .. name .. " (wezterm.lua)")
		for _, e in ipairs(table_) do
			local key, mods = norm(e.key, e.mods)
			line("  " .. pad(chord(key, mods), 24) .. " " .. M.describe(e.action))
		end
	end

	line()
	line("Chord audit")
	line(string.rep("-", 11))
	line(".  free    W  wezterm    S  " .. label .. "    s  shell/tty")
	line()
	local header = pad("", 12)
	for _, m in ipairs(GRID_MODS) do
		header = header .. pad(m, 14)
	end
	line(header)
	local rows = M.audit(config)
	local cell = {}
	for _, r in ipairs(rows) do
		cell[r.chord] = ({ free = ".", wezterm = "W", system = "S", shell = "s" })[r.status]
	end
	for _, k in ipairs(GRID_KEYS) do
		local row = pad(k, 12)
		for _, m in ipairs(GRID_MODS) do
			local key, mods = norm(k, m)
			row = row .. pad(cell[chord(key, mods)] or "?", 14)
		end
		line(row)
	end
	line()
	line("CTRL+<letter> alone is left out: the shell owns it. LEADER chords never reach the OS.")

	line()
	line(label .. " global shortcuts (the compositor/OS sees these before WezTerm)")
	line(string.rep("-", 40))
	local sys_rows = {}
	for _, v in pairs(system) do
		sys_rows[#sys_rows + 1] = v
	end
	table.sort(sys_rows, function(a, b)
		return a.chord < b.chord
	end)
	for _, v in ipairs(sys_rows) do
		line("  " .. pad(v.chord, 28) .. " " .. v.desc)
	end
	if is_mac then
		line("  (Apple defaults; verify in System Settings > Keyboard > Keyboard Shortcuts)")
	end
	line()
	line("Shell / tty chords (WezTerm passes these through unless bound)")
	line(string.rep("-", 40))
	local sh_rows = {}
	for _, v in pairs(shell) do
		sh_rows[#sh_rows + 1] = v
	end
	table.sort(sh_rows, function(a, b)
		return a.chord < b.chord
	end)
	for _, v in ipairs(sh_rows) do
		line("  " .. pad(v.chord, 28) .. " " .. v.desc)
	end

	line()
	line("KeyAssignment actions (wezterm.action.<Name>)")
	line(string.rep("-", 40))
	for _, group in ipairs(ACTIONS) do
		line()
		line(group[1])
		for _, n in ipairs(group[2]) do
			line("  " .. pad(n, 42) .. ACTIONS_DOC .. n .. ".html")
		end
	end
	line()
	line("Full list: " .. ACTIONS_DOC .. "index.html")
	line("Key names: https://wezterm.org/config/keys.html")
	line()
	return table.concat(out, "\n") .. "\n"
end

---------------------------------------------------------------------------
-- UI: InputSelector menus.
---------------------------------------------------------------------------

local function selector(title, choices, on_select)
	return act.InputSelector({
		title = title,
		choices = choices,
		fuzzy = true,
		fuzzy_description = "Type to filter " .. title:lower() .. ": ",
		action = wezterm.action_callback(function(window, pane, id, label)
			if id then
				on_select(window, pane, id, label)
			end
		end),
	})
end

local function bindings_selector(window)
	local config = window:effective_config()
	local list = M.bindings(config)
	local _, system = M.system_shortcuts()
	local choices = {}
	for i, b in ipairs(list) do
		local tag = b.source == "config" and "[cfg]" or (b.source == "override" and "[cfg*]" or "")
		local sys = system[chord_id(b.key, b.mods)]
		if sys then
			tag = tag .. " [SYS: " .. sys.desc .. "]"
		end
		choices[#choices + 1] = { id = tostring(i), label = pad(b.chord, 22) .. " " .. pad(b.desc, 52) .. " " .. tag }
	end
	return selector("Bindings", choices, function(w, p, id)
		local b = list[tonumber(id)]
		if b then
			w:perform_action(b.action, p)
		end
	end)
end

local function audit_selector(window)
	local rows = M.audit(window:effective_config())
	local choices = {}
	for i, r in ipairs(rows) do
		local status = ({ free = "free", wezterm = "wezterm: ", system = "system: ", shell = "shell: " })[r.status]
		choices[#choices + 1] = { id = tostring(i), label = pad(r.chord, 22) .. " " .. status .. r.desc }
	end
	return selector("Chord audit", choices, function(w, _, id)
		local r = rows[tonumber(id)]
		if not r then
			return
		end
		local snippet = string.format('{ key = "%s", mods = "%s", action = act.Nop },', r.key:gsub('"', '\\"'), r.mods)
		w:copy_to_clipboard(snippet, "Clipboard")
		w:toast_notification("keymap", "Copied: " .. snippet .. (r.status ~= "free" and ("\n(" .. r.status .. ": " .. r.desc .. ")") or ""), nil, 4000)
	end)
end

local function system_selector()
	local label, system = M.system_shortcuts()
	local shell = M.shell_shortcuts()
	local rows = {}
	for _, v in pairs(system) do
		rows[#rows + 1] = { chord = v.chord, desc = label .. ": " .. v.desc }
	end
	for _, v in pairs(shell) do
		rows[#rows + 1] = { chord = v.chord, desc = "shell: " .. v.desc }
	end
	table.sort(rows, function(a, b)
		return a.chord < b.chord
	end)
	local choices = {}
	for i, r in ipairs(rows) do
		choices[#choices + 1] = { id = tostring(i), label = pad(r.chord, 28) .. " " .. r.desc }
	end
	return selector("System shortcuts", choices, function(w, _, id)
		local r = rows[tonumber(id)]
		if r then
			w:copy_to_clipboard(r.chord, "Clipboard")
			w:toast_notification("keymap", "Copied: " .. r.chord, nil, 2000)
		end
	end)
end

local function actions_selector()
	local choices = {}
	for _, group in ipairs(ACTIONS) do
		for _, n in ipairs(group[2]) do
			choices[#choices + 1] = { id = n, label = pad(n, 42) .. group[1] }
		end
	end
	return selector("Actions", choices, function(_, _, id)
		wezterm.open_with(ACTIONS_DOC .. id .. ".html")
	end)
end

local function report_action(opts)
	return wezterm.action_callback(function(window, pane)
		local path = opts.report_path
		if not path then
			local dir = (os.getenv("XDG_CACHE_HOME") or (wezterm.home_dir .. "/.cache")) .. "/wezterm"
			wezterm.run_child_process({ "mkdir", "-p", dir })
			path = dir .. "/keymap.txt"
		end
		local f, err = io.open(path, "w")
		if not f then
			window:toast_notification("keymap", "cannot write " .. path .. ": " .. tostring(err), nil, 4000)
			return
		end
		f:write(M.report(window:effective_config()))
		f:close()
		window:perform_action(act.SpawnCommandInNewTab({ args = { "less", "-RS", path } }), pane)
	end)
end

function M.menu_action(opts)
	opts = opts or DEFAULTS
	local menu_key = opts.menu_key and chord(norm(opts.menu_key.key, opts.menu_key.mods)) or "keymap"
	return selector("Keymap", {
		{ id = "bindings", label = pad("Bindings", 20) .. "every active chord; Enter runs it" },
		{ id = "audit", label = pad("Chord audit", 20) .. "free / taken chords per modifier; Enter copies a config line" },
		{ id = "system", label = pad("System shortcuts", 20) .. "what the desktop and the shell grab first" },
		{ id = "actions", label = pad("Actions", 20) .. "KeyAssignment reference; Enter opens the docs" },
		{ id = "report", label = pad("Full report", 20) .. "everything as text in a new tab (" .. menu_key .. ")" },
	}, function(window, pane, id)
		if id == "bindings" then
			window:perform_action(bindings_selector(window), pane)
		elseif id == "audit" then
			window:perform_action(audit_selector(window), pane)
		elseif id == "system" then
			window:perform_action(system_selector(), pane)
		elseif id == "actions" then
			window:perform_action(actions_selector(), pane)
		elseif id == "report" then
			window:perform_action(report_action(opts), pane)
		end
	end)
end

---------------------------------------------------------------------------
-- Leader hints in the right status.
---------------------------------------------------------------------------

local function hint_text(window, entries, title)
	local parts = { { Attribute = { Intensity = "Bold" } }, { Text = title .. " " } }
	table.sort(entries, function(a, b)
		return a.key < b.key
	end)
	for _, e in ipairs(entries) do
		parts[#parts + 1] = { Attribute = { Intensity = "Bold" } }
		parts[#parts + 1] = { Text = e.key }
		parts[#parts + 1] = { Attribute = { Intensity = "Half" } }
		parts[#parts + 1] = { Text = " " .. e.desc .. "  " }
	end
	parts[#parts + 1] = "ResetAttributes"
	window:set_right_status(wezterm.format(parts))
end

local function install_hints()
	wezterm.on("update-status", function(window, _)
		local config = window:effective_config()
		local table_name = window:active_key_table()
		if table_name and config.key_tables and config.key_tables[table_name] then
			local entries = {}
			for _, e in ipairs(config.key_tables[table_name]) do
				local key, mods = norm(e.key, e.mods)
				entries[#entries + 1] = { key = chord(key, mods), desc = M.describe(e.action) }
			end
			hint_text(window, entries, table_name .. ":")
		elseif window:leader_is_active() then
			local entries = {}
			for _, e in ipairs(config.keys or {}) do
				local key, mods = norm(e.key, e.mods)
				if mods:find("LEADER", 1, true) then
					local extra = mods:gsub("LEADER|?", ""):gsub("|$", "")
					entries[#entries + 1] = { key = extra ~= "" and (extra .. "+" .. key) or key, desc = M.describe(e.action) }
				end
			end
			hint_text(window, entries, "LEADER")
		else
			window:set_right_status("")
		end
	end)
end

---------------------------------------------------------------------------
-- Entry point.
---------------------------------------------------------------------------

function M.apply_to_config(config, opts)
	opts = setmetatable(opts or {}, { __index = DEFAULTS })
	config.keys = config.keys or {}

	if opts.menu_key then
		config.keys[#config.keys + 1] = { key = opts.menu_key.key, mods = opts.menu_key.mods, action = M.menu_action(opts) }
	end

	if opts.leader_hints then
		install_hints()
		-- The status is redrawn on this interval; the leader is live for ~1s,
		-- so a shorter interval makes the hints appear while it still matters.
		if config.status_update_interval == nil then
			config.status_update_interval = 250
		end
	end

	if opts.warn_on_load then
		local label, system = M.system_shortcuts()
		for _, e in ipairs(config.keys) do
			local key, mods = norm(e.key, e.mods)
			local sys = system[chord_id(key, mods)]
			if sys then
				wezterm.log_warn(string.format("keymap: %s is also a %s shortcut (%s); the desktop gets it first", chord(key, mods), label, sys.desc))
			end
		end
	end
	return config
end

return M
