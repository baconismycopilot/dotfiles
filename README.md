# dotfiles

Python project environments driven by **mise + direnv + uv**, after
[Mise, Direnv and Python](https://www.gbb.is/posts/2024-07-24-mise-direnv-and-python/#layout_uvsh).

`cd` into a project and direnv:

1. `use mise` — puts the exact tool versions pinned in the project's `mise.toml`
   (or `.tool-versions`) on PATH, installing them if needed.
2. `layout uv` — installs the Python interpreter, creates `.venv`, runs
   `uv sync`, and activates the venv. Creates `pyproject.toml` via `uv init` if missing.

`cd` out and everything is unloaded again.

## Install

```sh
git clone git@github.com:baconismycopilot/dotfiles.git ~/repos/baconismycopilot/dotfiles
~/repos/baconismycopilot/dotfiles/install.sh
exec $SHELL
```

`install.sh` is idempotent and backs up anything it replaces to `*.bak`. It:

| step | what |
| --- | --- |
| mise | installs if missing: pacman on Arch, otherwise <https://mise.run> (macOS, Linux, WSL, Git Bash) |
| `mise/config.toml` | symlinked to `$XDG_CONFIG_HOME/mise/config.toml`; pins global `uv` and `direnv` |
| `direnv/lib/*.sh` | symlinked into `$XDG_CONFIG_HOME/direnv/lib/`; direnv auto-loads them |
| `direnv/direnv.toml` | symlinked; raises the slow-`.envrc` warning to 1m for `uv sync` |
| `mise install` | installs the global tools above |
| `zsh/` | if `zsh` is present: installs oh-my-zsh, powerlevel10k, zsh-syntax-highlighting (skipped on CachyOS), neovim, then symlinks every file under `zsh/` into `$HOME` (differing files backed up). Per-host edits go in `~/.zshrc.local` |
| `shell/mise.sh` | linked to `$XDG_CONFIG_HOME/shell/mise.sh` and sourced by the repo `~/.zshrc`; hooked into `~/.bashrc`; `shell/mise.fish` linked into fish `conf.d/` |
| gitleaks | installed if missing; `core.hooksPath` set to `.githooks` so the pre-push secrets scan runs |
| `wezterm/*.lua` | symlinked into `$XDG_CONFIG_HOME/wezterm/` |
| `kitty/*.conf` | symlinked into `$XDG_CONFIG_HOME/kitty/`; Hack Nerd Font installed if `kitty` is present and the font is missing |

Supported: macOS, Linux, WSL with bash, zsh or fish. Native Windows has no
direnv shell hook; use WSL.

## Shell (zsh)

This repo also carries my interactive zsh setup (oh-my-zsh + Powerlevel10k).
`install.sh` installs the prerequisites and symlinks each file under `zsh/`
into `$HOME`, so `p10k configure` and any edit show up in `git status`.
Per-host tweaks go in `~/.zshrc.local`, which `.zshrc` sources last. Any
differing file it would replace is backed up to `*.bak`.

- **CachyOS:** if `/usr/share/cachyos-zsh-config/cachyos-config.zsh` exists,
  `~/.zshrc` sources it instead of `~/.oh-my-zsh`. That gives the pacman-packaged
  oh-my-zsh, powerlevel10k, syntax highlighting, autosuggestions, history
  substring search and pkgfile's command-not-found handler, and `install.sh`
  skips the oh-my-zsh install and git clones.
- **Per-host overrides:** `~/.zshrc` sources `~/.zshrc.local` (git-ignored) if
  present. Put machine-specific PATH entries and aliases there, e.g.
  `alias superbacon='ssh user@192.168.x.x'`.
- **Secrets:** nothing secret is tracked. Anything credential-like belongs in
  `~/.zshrc.local` or outside the repo entirely.
- **direnv** is hooked once, by `shell/mise.sh` (the oh-my-zsh direnv plugin is
  intentionally omitted), so the mise + direnv + uv workflow above works
  unchanged under zsh. `~/.zshrc` runs `direnv export` before the p10k instant
  prompt so direnv output never triggers p10k's console-output warning.

zsh-specific; bash/fish users get the Python workflow above but not this.

## Terminal (WezTerm)

`wezterm/wezterm.lua` is the one terminal config for every OS. `install.sh`
symlinks it to `$XDG_CONFIG_HOME/wezterm/wezterm.lua`; WezTerm reloads it on
save. Window-level chords use `SUPER` on macOS and `ALT` on Linux, chosen from
`wezterm.target_triple` at load time, so the same file gives the same chords
on both without a per-host copy. Pane management goes through a tmux-style
leader, `Ctrl+A` then a key, so it never collides with shell or editor keys.

| key (macOS / Linux) | action |
| --- | --- |
| `Cmd+D` / `Alt+D`, with `Shift` | split pane side by side / stacked |
| `Ctrl+A` then `\|` / `-` | split pane side by side / stacked |
| `Ctrl+A` then `H` `J` `K` `L` | move between panes |
| `Ctrl+A` then `Z` | zoom the current pane |
| `Ctrl+A` then `A` | send a literal `Ctrl+A` to the shell |
| `Cmd+T` / `Alt+T` | new tab |
| `Cmd+W` / `Alt+W` | close pane (asks first) |
| `Cmd+[` `Cmd+]` / `Alt+[` `Alt+]` | previous / next tab |
| `Cmd+Return` / `Alt+Return` | toggle fullscreen |
| `Cmd+K` / `Alt+K` | clear scrollback and screen |
| `Cmd+U` / `Alt+U` | toggle 90% window opacity |
| `Ctrl+Shift+L` | toggle font ligatures |
| `Ctrl+Backspace` | delete previous word (sends `Ctrl+W`) |

Font stack is JetBrains Mono with Nerd Font symbols as fallback. WezTerm
bundles both, so nothing needs installing for the Powerlevel10k glyphs.

The table above is a summary. `wezterm/keymap.lua` is a small plugin, loaded
by `wezterm.lua`, that shows the real state from inside WezTerm:

- **Leader popup.** `Ctrl+A` opens an overlay listing every leader key with
  a short label (`h  pane ←`, `|  split │`, ...). Press the key and it runs;
  `Esc` cancels, `/` filters. The overlay only sees unshifted keys, so a
  shifted leader key is reached through its unshifted twin (`|` via `\`) or a
  spare digit (`?` via `1`); the row says which. This replaces WezTerm's native
  leader, which has no way to show hints, so the leader timeout no longer
  applies.
- **Keymap menu** on `Ctrl+A` then `?`, fuzzy-searchable:

  | entry | what |
  | --- | --- |
  | Bindings | pick a modifier set (row shows the count and class mix), then every chord in it. Enter runs it |
  | Chord audit | pick a modifier set, then every key marked free / wezterm / OS / shell. Enter copies a `{ key = ..., mods = ..., action = ... }` line |
  | System shortcuts | KDE Plasma globals from `~/.config/kglobalshortcutsrc`, or Apple's macOS defaults, plus the `Ctrl`/`Alt` chords the shell uses |
  | Actions | `KeyAssignment` reference; Enter opens the docs page |
  | Full report | all of the above as text in a new tab |

  Rows are coloured by class: blue built-in WezTerm binding, green yours (or a
  free chord), yellow a custom binding that replaced a default, red the OS
  grabs it first, purple the shell uses it.

- **Load-time warnings.** A custom chord that a desktop shortcut shadows is
  reported with `wezterm.log_warn` (visible in the debug overlay, "Show debug
  overlay" in the command palette).

Options are passed to `keymap.apply_to_config(config, opts)`: `menu_key`
(default `?` with `LEADER|SHIFT`), `popup`, `labels` (override a popup label
by key, e.g. `{ ["|"] = "split side by side" }`), `warn_on_load`,
`report_path`. Inside WezTerm, `Ctrl+Shift+P` opens the command palette, which
also lists every action with its binding.

## Terminal (kitty)

`kitty/` is the same setup for [kitty](https://sw.kovidgoyal.net/kitty/), split
into one file per section of the
[kitty.conf reference](https://sw.kovidgoyal.net/kitty/conf/). `kitty.conf`
holds nothing but `include` lines; `install.sh` symlinks every file into
`$XDG_CONFIG_HOME/kitty/` and kitty reloads on save. Relative includes resolve
next to the symlink, so a git-ignored `~/.config/kitty/local.conf` is the
per-host file (`globinclude`, so a missing file is silent). The OS split is
kitty's own `${KITTY_OS}` variable: `macos.conf` or `linux.conf` is included
last and may override anything (Linux sets a smaller `font_size`).

| file | section | what changes from the defaults |
| --- | --- | --- |
| `fonts.conf` | Fonts | Hack Nerd Font Mono, 13 pt (kitty bundles no fonts) |
| `cursor.conf` | Text cursor | defaults, stated |
| `scrollback.conf` | Scrollback | 20000 lines, 10 MB pager history |
| `mouse.conf` | Mouse | strip trailing spaces on copy |
| `bell.conf` | Terminal bell | flash instead of beep |
| `window.conf` | Window layout | `splits` layout first, padding, close confirmation |
| `tabs.conf` | Tab bar | bottom, always shown, powerline style |
| `colors.conf` | Color scheme | One Dark from `kitten themes --dump-theme`, dynamic opacity on |
| `advanced.conf` | Advanced | shell integration on, remote control off, update check off, notify when a long command finishes |
| `keybindings.conf` | Keyboard shortcuts | leader sequences below, on top of every kitty default |
| `keybindings-macos.conf`, `keybindings-linux.conf` | Keyboard shortcuts | the `Cmd` / `Alt` chords below |
| `macos.conf`, `linux.conf` | OS specific tweaks | left Option as Alt; Linux font size |

The bindings mirror the WezTerm table. A kitty "window" is a WezTerm pane.

| key (macOS / Linux) | action |
| --- | --- |
| `Cmd+D` / `Alt+D`, with `Shift` | split window side by side / stacked |
| `Ctrl+A` then `\|` / `-` | split window side by side / stacked |
| `Ctrl+A` then `H` `J` `K` `L` | move between windows |
| `Ctrl+A` then `Z` | zoom (toggle the `stack` layout) |
| `Ctrl+A` then `Ctrl+A` | send a literal `Ctrl+A` to the shell |
| `Ctrl+A` then `?` | command palette (every action with its binding) |
| `Cmd+T` / `Alt+T` | new tab |
| `Cmd+W` / `Alt+W` | close window (asks first) |
| `Cmd+[` `Cmd+]` / `Alt+[` `Alt+]` | previous / next tab |
| `Cmd+Return` / `Alt+Return` | toggle fullscreen |
| `Cmd+K` / `Alt+K` | clear scrollback and screen |
| `Cmd+U` / `Alt+U`, with `Shift` | 90% window opacity / back to default |
| `Ctrl+Shift+Alt+L`, with `Shift` | ligatures off / on in this window |
| `Ctrl+Backspace` | delete previous word (sends `Ctrl+W`) |

Three macOS defaults are replaced: `Cmd+W` (was close tab), `Cmd+Return` (was
new window) and `Cmd+K` (was clear to cursor). Everything else kitty binds by
default still works, in particular `Ctrl+Shift+F5` reload, `Ctrl+Shift+F6`
effective config, `Ctrl+Shift+F3` command palette, `Ctrl+Shift+E` open a URL
by hint, `Ctrl+Shift+H` scrollback in a pager and `Ctrl+Shift+G` the last
command's output. Differences from WezTerm: kitty has no toggle actions, so
opacity and ligatures are pairs, and there is no keymap plugin; the command
palette is the equivalent. `kitten themes --config-file-name colors.conf` and
`kitten choose-fonts --config-file-name fonts.conf` change theme and font and
write into the component file instead of `kitty.conf`.

## Repo management

`main` is protected by a GitHub ruleset: pull request required, linear history,
no force pushes, no deletions, no bypass for anyone. Work on a branch and merge
via PR.

Secrets are blocked at three layers: GitHub secret scanning with push
protection, a local `pre-push` hook running [gitleaks](https://github.com/gitleaks/gitleaks),
and a Claude Code hook in `.claude/settings.json`. Enable the local hook once
per clone:

```sh
brew install gitleaks            # macOS; Arch/CachyOS: sudo pacman -S gitleaks
git config core.hooksPath .githooks
```

`install.sh` does both (gitleaks only if missing).

## New project

```sh
bin/uv-init ~/code/myproject   # mkdir, mise.toml, .envrc, mise install, direnv allow
cd ~/code/myproject
which python                   # -> ~/code/myproject/.venv/bin/python
```

Or by hand, exactly as in the post:

```sh
mkdir myproject && cd myproject
printf '[tools]\nuv = "0.13.1"\n' > mise.toml
printf 'use mise\nlayout uv\n' > .envrc    # `use mise` must be first
direnv allow
```

Pin the interpreter with `.python-version` or `requires-python` in
`pyproject.toml`; uv installs it. Poetry and pip projects use `layout poetry`
/ `layout pip` the same way.

## Layout

```
direnv/lib/use_mise.sh        use mise
direnv/lib/layout_uv.sh       layout uv
direnv/lib/layout_poetry.sh   layout poetry
direnv/lib/layout_pip.sh      layout pip
direnv/direnv.toml            direnv global config
mise/config.toml              mise global config (uv, direnv)
shell/mise.sh, mise.fish      PATH (mise bin + shims) and direnv hook
templates/envrc, mise.toml    copied by bin/uv-init
bin/uv-init                   scaffold a project
zsh/.zshrc .zprofile .zshenv .p10k.zsh   zsh + oh-my-zsh + powerlevel10k (symlinked into $HOME)
zsh/.config/shell/vims.env               nvim NVIM_APPNAME aliases
zsh/.config/shell/onedark-*.zsh          onedark colors for zsh-syntax-highlighting
wezterm/wezterm.lua           WezTerm config (symlinked to $XDG_CONFIG_HOME/wezterm/)
wezterm/keymap.lua            keymap plugin: leader hints, bindings/free-chord/OS-shortcut menu
kitty/kitty.conf              kitty entry point, includes only (symlinked to $XDG_CONFIG_HOME/kitty/)
kitty/*.conf                  one file per kitty.conf section; keybindings-<os>.conf, <os>.conf per OS
install.sh                    bootstrap
```

## Differences from the post

- **No `mise direnv exec`.** mise has deprecated `mise direnv` and the `use mise`
  integration (removal planned for 2027.10.4). `use_mise.sh` gets the same effect
  with the stable `direnv_load mise exec -- direnv dump`, and `mise exec`
  auto-installs missing tools, so `mise install` by hand is optional.
- **No `mise activate` in the shell rc.** mise documents its shell hook and
  direnv's as conflicting over PATH. direnv owns activation here; mise's
  `shims/` directory is on PATH so global tools work outside projects.
- **Portable.** `command -v`/`grep` replace `which`/`rg`; venv `Scripts/`
  (Windows) is handled alongside `bin/`; `mise.toml` is watched as well as
  `.tool-versions`, and `pyproject.toml` / `uv.lock` / `.python-version` trigger
  a re-sync.
- `mise.toml` is used instead of `.tool-versions` (both work).

## Caveats

- Edits to `mise.toml` in a project reload automatically; global
  `~/.config/mise/config.toml` changes need `direnv reload` in open projects.
- Keep mise's `python.uv_venv_auto` off (it is, in `mise/config.toml`) so mise
  never activates a venv on top of direnv's.
