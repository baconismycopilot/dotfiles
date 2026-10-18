#!/usr/bin/env bash
# Bootstrap mise + direnv + uv workflow from this repo.
#
# Works on macOS, Linux and WSL (bash, zsh, fish). Native Windows: direnv has
# no PowerShell hook; use WSL (or Git Bash, which this script also handles).
#
# What it does (all idempotent, existing files are backed up to *.bak):
#   1. install mise if missing (https://mise.run)
#   2. symlink mise/config.toml      -> $XDG_CONFIG_HOME/mise/config.toml
#   3. symlink direnv/lib/*.sh       -> $XDG_CONFIG_HOME/direnv/lib/   (use mise, layout uv|poetry|pip)
#      symlink direnv/direnv.toml    -> $XDG_CONFIG_HOME/direnv/direnv.toml
#   4. mise install                  (uv, direnv from mise/config.toml)
#   5. hook shell/mise.sh into ~/.zshrc / ~/.bashrc, shell/mise.fish into fish conf.d
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

# 1. mise
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

# 5. shell hooks
[ -f "$HOME/.zshrc" ]  || [ "${SHELL##*/}" = "zsh" ]  && ensure_line "$HOME/.zshrc"  "[ -r \"$REPO/shell/mise.sh\" ] && source \"$REPO/shell/mise.sh\""
[ -f "$HOME/.bashrc" ] || [ "${SHELL##*/}" = "bash" ] && ensure_line "$HOME/.bashrc" "[ -r \"$REPO/shell/mise.sh\" ] && source \"$REPO/shell/mise.sh\""
if [ -d "$XDG_CONFIG_HOME/fish" ] || command -v fish >/dev/null 2>&1; then
    link "$REPO/shell/mise.fish" "$XDG_CONFIG_HOME/fish/conf.d/mise.fish"
fi

say "done. Open a new shell, then: $REPO/bin/uv-init ~/code/myproject"
