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
| mise | installs via <https://mise.run> if missing (macOS, Linux, WSL, Git Bash) |
| `mise/config.toml` | symlinked to `$XDG_CONFIG_HOME/mise/config.toml`; pins global `uv` and `direnv` |
| `direnv/lib/*.sh` | symlinked into `$XDG_CONFIG_HOME/direnv/lib/`; direnv auto-loads them |
| `direnv/direnv.toml` | symlinked; raises the slow-`.envrc` warning to 1m for `uv sync` |
| `mise install` | installs the global tools above |
| `zsh/` | if `zsh` is present: installs oh-my-zsh, powerlevel10k, zsh-syntax-highlighting, neovim, then **copies** `zsh/` into `$HOME` (existing files backed up). Not symlinked, so per-host edits stay local |
| `shell/mise.sh` | sourced from `~/.zshrc` / `~/.bashrc`; `shell/mise.fish` linked into fish `conf.d/` |

Supported: macOS, Linux, WSL with bash, zsh or fish. Native Windows has no
direnv shell hook; use WSL.

## Shell (zsh)

This repo also carries my interactive zsh setup (oh-my-zsh + Powerlevel10k).
`install.sh` installs the prerequisites and **copies** the `zsh/` files into
`$HOME` — copied, not symlinked, so per-host tweaks stay out of the repo. Any
file it would overwrite is backed up to `*.bak.<timestamp>`.

- **Per-host overrides:** `~/.zshrc` sources `~/.zshrc.local` (git-ignored) if
  present. Put machine-specific PATH entries and aliases there, e.g.
  `alias superbacon='ssh user@192.168.x.x'`.
- **Secrets:** nothing secret is tracked. `~/.local/user-secrets/bs-be18000.env`
  is scaffolded from `examples/bs-be18000.env.example`; fill in real values.
- **direnv** is hooked once, by `shell/mise.sh` (the oh-my-zsh direnv plugin is
  intentionally omitted), so the mise + direnv + uv workflow above works
  unchanged under zsh.

zsh-specific; bash/fish users get the Python workflow above but not this.

## Repo management

`main` is protected by a GitHub ruleset: pull request required, linear history,
no force pushes, no deletions, no bypass for anyone. Work on a branch and merge
via PR.

Secrets are blocked at three layers: GitHub secret scanning with push
protection, a local `pre-push` hook running [gitleaks](https://github.com/gitleaks/gitleaks),
and a Claude Code hook in `.claude/settings.json`. Enable the local hook once
per clone:

```sh
brew install gitleaks
git config core.hooksPath .githooks
```

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
zsh/.zshrc .zprofile .zshenv .p10k.zsh   zsh + oh-my-zsh + powerlevel10k (copied to $HOME)
zsh/.config/shell/vims.env               nvim NVIM_APPNAME aliases
zsh/.config/shell/onedark-*.zsh          onedark colors for zsh-syntax-highlighting
examples/bs-be18000.env.example          template for a machine-local secret
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
