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
| `wezterm/wezterm.lua` | symlinked to `$XDG_CONFIG_HOME/wezterm/wezterm.lua` |

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
- **Secrets:** nothing secret is tracked. `~/.local/user-secrets/bs-be18000.env`
  is scaffolded from `examples/bs-be18000.env.example`; fill in real values. It
  is loaded only when running `bs-be18000` (a wrapper function in `~/.zshrc`),
  not exported to every process.
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
| `Ctrl+A` then `Ctrl+A` | send a literal `Ctrl+A` to the shell |
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

The table above is a summary. `bin/wezterm-keys` reads the real state from
WezTerm itself (`wezterm show-keys`) and from the desktop, so it stays correct
as the config changes:

```sh
bin/wezterm-keys          # every effective binding, grouped by modifier;
                          # [cfg] = set in wezterm.lua, [SYS] = the desktop grabs it first
bin/wezterm-keys free     # grid of unbound chords per modifier set
bin/wezterm-keys system   # KDE Plasma (from kglobalshortcutsrc) or macOS global shortcuts,
                          # plus the CTRL chords the shell owns
bin/wezterm-keys actions  # KeyAssignment names you can map, with doc links
bin/wezterm-keys tables   # copy_mode and search_mode key tables
```

Inside WezTerm, `Ctrl+Shift+P` opens the command palette, which also lists
every action with its binding. Needs `python3` (stdlib only) and `wezterm` on
PATH; on macOS the binary inside WezTerm.app is found automatically.

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
bin/wezterm-keys              list WezTerm bindings, free chords, OS-reserved shortcuts
zsh/.zshrc .zprofile .zshenv .p10k.zsh   zsh + oh-my-zsh + powerlevel10k (symlinked into $HOME)
zsh/.config/shell/vims.env               nvim NVIM_APPNAME aliases
zsh/.config/shell/onedark-*.zsh          onedark colors for zsh-syntax-highlighting
examples/bs-be18000.env.example          template for a machine-local secret
wezterm/wezterm.lua           WezTerm config (symlinked to $XDG_CONFIG_HOME/wezterm/)
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
