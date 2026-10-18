# shellcheck shell=sh
# Sourced from ~/.zshrc and ~/.bashrc by install.sh.
#
# Design: direnv drives mise (`use mise` in .envrc), so we do NOT run
# `eval "$(mise activate ...)"` — mise documents the two hooks as conflicting.
# Instead, mise's shims directory goes on PATH so globally pinned tools
# (uv, direnv, ...) work everywhere, and direnv swaps in exact project versions.

# mise itself (default install location of https://mise.run)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# mise shims for globally pinned tools
_mise_shims="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims"
if [ -d "$_mise_shims" ]; then
    case ":$PATH:" in
        *":$_mise_shims:"*) ;;
        *) export PATH="$_mise_shims:$PATH" ;;
    esac
fi
unset _mise_shims

# direnv hook (idempotent; direnv's own hook guards against double registration)
if command -v direnv >/dev/null 2>&1; then
    if [ -n "${ZSH_VERSION:-}" ]; then
        eval "$(direnv hook zsh)"
    elif [ -n "${BASH_VERSION:-}" ]; then
        eval "$(direnv hook bash)"
    fi
fi
