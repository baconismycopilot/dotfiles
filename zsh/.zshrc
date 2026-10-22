# CachyOS ships oh-my-zsh, powerlevel10k and the zsh plugins as pacman packages,
# wired up by its own config file. When present, use it instead of installing a
# second oh-my-zsh into ~/.oh-my-zsh. That file also enables the p10k instant
# prompt and sources ~/.p10k.zsh, so both are skipped below on CachyOS.
_cachyos_zsh=/usr/share/cachyos-zsh-config/cachyos-config.zsh

# Keep $path (and $PATH) free of duplicate entries automatically.
typeset -U path PATH

# Homebrew (macOS: Apple Silicon or Intel). No-op on Linux (e.g. CachyOS uses pacman).
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x $_brew ]]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew

# Personal/tool bin directories, highest priority first.
# Python is managed by uv; `python`/`python3` are uv-managed symlinks in
# ~/.local/bin (see `uv python install --default`).
path=(
  "$HOME/bin"
  "$HOME/.local/bin"
  $path
  /usr/local/bin
)
# Optional tool dirs — only add when present on this host.
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)   # Rust/cargo
[[ -d "$HOME/.rd/bin" ]]    && path=("$HOME/.rd/bin" $path)      # Rancher Desktop (macOS)
[[ -d "$HOME/go/bin" ]]     && path+=("$HOME/go/bin")             # Go (go install)

# mise + direnv: puts mise and its shims on PATH and registers the direnv hook
# (linked here by install.sh). Then load the current directory's .envrc now,
# before the p10k instant prompt, so direnv's "loading" output can't trip
# p10k's console-output warning. Both run after the PATH setup above so a
# project venv stays ahead of ~/.local/bin.
[ -r "$HOME/.config/shell/mise.sh" ] && source "$HOME/.config/shell/mise.sh"
(( ${+commands[direnv]} )) && emulate zsh -c "$(direnv export zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ ! -r $_cachyos_zsh && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


if [[ -r $_cachyos_zsh ]]; then
  # CachyOS: oh-my-zsh (plugins git fzf extract), powerlevel10k,
  # zsh-syntax-highlighting, zsh-autosuggestions, zsh-history-substring-search
  # and the pkgfile command-not-found handler, all from /usr/share.
  source "$_cachyos_zsh"
  # CachyOS defines this in double quotes, so $(pacman -Qtdq) runs once at
  # shell startup instead of when the alias is used.
  alias cleanup='sudo pacman -Rsn $(pacman -Qtdq)'
else
  # Path to your oh-my-zsh installation.
  export ZSH="$HOME/.oh-my-zsh"

  # Powerlevel10k, installed as an oh-my-zsh custom theme (see install.sh). This
  # works the same on macOS (brew) and Linux without hardcoding a package path.
  ZSH_THEME="powerlevel10k/powerlevel10k"

  # See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
  # Uncomment the following line to use case-sensitive completion.
  # CASE_SENSITIVE="true"

  # Uncomment the following line to use hyphen-insensitive completion.
  # Case-sensitive completion must be off. _ and - will be interchangeable.
  # HYPHEN_INSENSITIVE="true"

  # Uncomment one of the following lines to change the auto-update behavior
  # zstyle ':omz:update' mode disabled  # disable automatic updates
  # zstyle ':omz:update' mode auto      # update automatically without asking
  # zstyle ':omz:update' mode reminder  # just remind me to update when it's time

  # Uncomment the following line to change how often to auto-update (in days).
  # zstyle ':omz:update' frequency 13

  # Uncomment the following line if pasting URLs and other text is messed up.
  # DISABLE_MAGIC_FUNCTIONS="true"

  # Uncomment the following line to disable colors in ls.
  # DISABLE_LS_COLORS="true"

  # Uncomment the following line to disable auto-setting terminal title.
  # DISABLE_AUTO_TITLE="true"

  # Uncomment the following line to enable command auto-correction.
  # ENABLE_CORRECTION="true"

  # Which plugins would you like to load?
  # Standard plugins can be found in $ZSH/plugins/
  # Custom plugins may be added to $ZSH_CUSTOM/plugins/
  # Add wisely, as too many plugins slow down shell startup.
  # NOTE: direnv is hooked by shell/mise.sh (sourced near the top of this file),
  # so the oh-my-zsh direnv plugin is intentionally omitted here to avoid hooking
  # direnv twice.
  # zsh-syntax-highlighting is installed as a custom plugin by install.sh and must
  # stay last so it can wrap every widget defined by the other plugins.
  plugins=(zsh-syntax-highlighting)

  source "$ZSH/oh-my-zsh.sh"
fi

# Onedark colors for zsh-syntax-highlighting. Sourced AFTER oh-my-zsh.sh so the
# highlighting engine (loaded via the plugin above) is already active.
[ -r "$HOME/.config/shell/onedark-zsh-syntax-highlighter.zsh" ] && \
  source "$HOME/.config/shell/onedark-zsh-syntax-highlighter.zsh"

# User configuration

# Preferred editor for local and remote sessions.
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
elif command -v nvim >/dev/null 2>&1; then
    export EDITOR='nvim'
else
    export EDITOR='vim'
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -r $_cachyos_zsh || ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
unset _cachyos_zsh

# Load bs-be18000 credentials only for that command, in a subshell, so they are
# not exported to every process started from this shell.
bs-be18000() {
  (
    [ -r "$HOME/.local/user-secrets/bs-be18000.env" ] && source "$HOME/.local/user-secrets/bs-be18000.env"
    command bs-be18000 "$@"
  )
}

[ -r "$HOME/.config/shell/vims.env" ] && source "$HOME/.config/shell/vims.env"

set -o vi

# LM Studio CLI (lms) — only if installed (macOS).
[[ -d "$HOME/.lmstudio/bin" ]] && export PATH="$PATH:$HOME/.lmstudio/bin"

# Per-host overrides — NOT tracked in the dotfiles repo. Put machine-specific
# PATH entries, aliases (e.g. ssh shortcuts), and tweaks here. Example:
#   alias superbacon='ssh user@192.168.x.x'
[ -r "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
