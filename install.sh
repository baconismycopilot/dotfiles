#!/usr/bin/env bash
# Bootstrap mise + direnv + uv workflow from this repo.
#
# Works on macOS, Linux and WSL (bash, zsh, fish). Native Windows: direnv has
# no PowerShell hook; use WSL (or Git Bash, which this script also handles).
#
# What it does (all idempotent, existing files are backed up to *.bak):
#   1. install mise if missing (pacman on Arch, else https://mise.run)
#   2. symlink mise/config.toml      -> $XDG_CONFIG_HOME/mise/config.toml
#   3. symlink direnv/lib/*.sh       -> $XDG_CONFIG_HOME/direnv/lib/   (use mise, layout uv|poetry|pip)
#      symlink direnv/direnv.toml    -> $XDG_CONFIG_HOME/direnv/direnv.toml
#   4. mise install                  (uv, direnv from mise/config.toml)
#   4b. zsh (if present): oh-my-zsh + powerlevel10k + zsh-syntax-highlighting
#       (skipped on CachyOS, which ships them as packages) + neovim, then copy
#       zsh/ into $HOME (backing up existing files)
#   5. link shell/mise.sh -> $XDG_CONFIG_HOME/shell/mise.sh (sourced by zsh/.zshrc),
#      hook it into ~/.bashrc, link shell/mise.fish into fish conf.d
#   6. gitleaks (if missing) + core.hooksPath=.githooks for the pre-push secrets scan
#   7. symlink wezterm/wezterm.lua   -> $XDG_CONFIG_HOME/wezterm/wezterm.lua
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
MISE_BIN="$HOME/.local/bin/mise"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }

# link SRC DST — replace DST with a symlink to SRC, backing up any real file.
link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        warn "backing up $dst -> $dst.bak"
        mv -f "$dst" "$dst.bak"
    fi
    ln -s "$src" "$dst"
    say "linked $dst -> $src"
}

# ensure_line FILE LINE — append LINE to FILE if not already present.
ensure_line() {
    local file="$1" line="$2"
    [ -f "$file" ] || touch "$file"
    if ! grep -qxF "$line" "$file"; then
        printf '\n# mise + direnv (baconismycopilot/dotfiles)\n%s\n' "$line" >> "$file"
        say "added hook to $file"
    fi
}

OS="$(uname -s)"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
# CachyOS's own zsh config; zsh/.zshrc sources it instead of ~/.oh-my-zsh when present.
CACHYOS_ZSH=/usr/share/cachyos-zsh-config/cachyos-config.zsh

# pkg_install PKGS... — install packages with the platform package manager.
pkg_install() {
    case "$OS" in
        Darwin)
            command -v brew >/dev/null 2>&1 || { warn "Homebrew not found; skipping: $*"; return 0; }
            brew install "$@" ;;
        Linux)
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm "$@"
            elif command -v yay >/dev/null 2>&1; then
                yay -S --needed --noconfirm "$@"
            else
                warn "no pacman/yay found; skipping: $*"
            fi ;;
        *) warn "unsupported OS $OS; skipping: $*" ;;
    esac
}

# clone_if_missing REPO DST — shallow clone REPO to DST unless it already exists.
clone_if_missing() {
    [ -d "$2" ] && return
    say "cloning $(basename "$2")"
    git clone --depth=1 "$1" "$2"
}

# copy_tree SRC DST — copy every file under SRC into DST, backing up changed files.
copy_tree() {
    local src="$1" dst="$2" ts rel target
    ts="$(date +%Y%m%d%H%M%S)"
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        target="$dst/$rel"
        mkdir -p "$(dirname "$target")"
        if [ -e "$target" ] && ! cmp -s "$f" "$target"; then
            cp -p "$target" "$target.bak.$ts"
            say "backed up $rel -> $rel.bak.$ts"
        fi
        cp "$f" "$target"
    done < <(find "$src" -type f -print0)
}

# 1. mise
if ! command -v mise >/dev/null 2>&1 && [ ! -x "$MISE_BIN" ] && command -v pacman >/dev/null 2>&1; then
    say "installing mise"
    pkg_install mise
fi
if ! command -v mise >/dev/null 2>&1 && [ ! -x "$MISE_BIN" ]; then
    case "$(uname -s)" in
        Darwin|Linux|MINGW*|MSYS*|CYGWIN*)
            say "installing mise"
            curl -fsSL https://mise.run | sh ;;
        *)
            echo "unsupported OS $(uname -s); install mise manually: https://mise.jdx.dev/getting-started.html" >&2
            exit 1 ;;
    esac
fi
export PATH="$HOME/.local/bin:$PATH"
say "mise $(mise --version)"

# 2. mise global config
link "$REPO/mise/config.toml" "$XDG_CONFIG_HOME/mise/config.toml"

# 3. direnv library + config
for f in "$REPO"/direnv/lib/*.sh; do
    link "$f" "$XDG_CONFIG_HOME/direnv/lib/$(basename "$f")"
done
link "$REPO/direnv/direnv.toml" "$XDG_CONFIG_HOME/direnv/direnv.toml"

# 4. global tools (uv, direnv)
say "installing global tools"
mise install --yes
mise reshim >/dev/null 2>&1 || true

# 4b. zsh config (oh-my-zsh + powerlevel10k + zsh-syntax-highlighting + CLI tools)
if command -v zsh >/dev/null 2>&1; then
    say "setting up zsh config"

    if [ -r "$CACHYOS_ZSH" ]; then
        say "CachyOS zsh config found; using its packaged oh-my-zsh, powerlevel10k and plugins"
    else
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            say "installing oh-my-zsh"
            # KEEP_ZSHRC=yes so the installer does not clobber the .zshrc we copy below.
            RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        fi

        clone_if_missing https://github.com/romkatv/powerlevel10k.git \
            "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
        clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git \
            "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
    fi

    if ! command -v nvim >/dev/null 2>&1; then
        say "installing neovim"
        pkg_install neovim || warn "neovim failed to install; continuing"
    fi

    say "copying zsh dotfiles into \$HOME (existing files backed up to *.bak.<ts>)"
    copy_tree "$REPO/zsh" "$HOME"

    # Machine-local secret scaffold — never tracked by git.
    mkdir -p "$HOME/.local/user-secrets"
    if [ ! -e "$HOME/.local/user-secrets/bs-be18000.env" ]; then
        cp "$REPO/examples/bs-be18000.env.example" "$HOME/.local/user-secrets/bs-be18000.env"
        say "created ~/.local/user-secrets/bs-be18000.env from example (fill it in)"
    fi
else
    warn "zsh not found; skipping zsh config"
fi

# 5. shell hooks. zsh/.zshrc sources the linked mise.sh itself, so ~/.zshrc is
# not appended to (that would make every re-run back up and re-copy it).
link "$REPO/shell/mise.sh" "$XDG_CONFIG_HOME/shell/mise.sh"
[ -f "$HOME/.bashrc" ] || [ "${SHELL##*/}" = "bash" ] && ensure_line "$HOME/.bashrc" "[ -r \"$REPO/shell/mise.sh\" ] && source \"$REPO/shell/mise.sh\""
if [ -d "$XDG_CONFIG_HOME/fish" ] || command -v fish >/dev/null 2>&1; then
    link "$REPO/shell/mise.fish" "$XDG_CONFIG_HOME/fish/conf.d/mise.fish"
fi

# 6. secrets scanning for this clone: gitleaks + the pre-push hook
if ! command -v gitleaks >/dev/null 2>&1; then
    say "installing gitleaks"
    pkg_install gitleaks || warn "gitleaks failed to install; pushes from this clone will be blocked"
fi
git -C "$REPO" config core.hooksPath .githooks

# 7. WezTerm config. Symlinked, not copied: it carries no per-host state, and the
# keybindings pick SUPER or ALT from wezterm.target_triple at load time.
link "$REPO/wezterm/wezterm.lua" "$XDG_CONFIG_HOME/wezterm/wezterm.lua"

say "done. Open a new shell, then: $REPO/bin/uv-init ~/code/myproject"
