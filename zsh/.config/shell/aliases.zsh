# Shared zsh aliases, tracked in the dotfiles repo and symlinked to
# ~/.config/shell/aliases.zsh by install.sh. Sourced by .zshrc before
# ~/.zshrc.local, so a host file can override anything here.
#
# Rules (the repo is public):
#   - nothing host-specific: no hostnames, IPs, usernames or local paths;
#     those go in ~/.zshrc.local
#   - distro-specific aliases (pacman, brew) go in the matching branch of
#     .zshrc, next to `cleanup`
#   - nvim NVIM_APPNAME aliases stay in vims.env
#   - single quotes unless the expansion must happen at definition time

# ls family via eza (https://github.com/eza-community/eza). Names mirror the
# oh-my-zsh set (ls l ll la lsa) so they override it wherever eza exists and
# the stock oh-my-zsh ls aliases survive on hosts without eza. In eza -h is
# --header (sizes are human-readable already) and -a skips . and .. (-aa
# shows them), so l, la and lsa come out the same. Icons need a Nerd Font,
# which kitty/fonts.conf sets; --icons=auto drops them when piped.
# Git columns: --git is per-file status inside a repo (M, N, I...). --git-repos
# adds a column for subdirectories that are repo roots: dirty marker plus
# branch, handy in a directory full of clones. lg is the git-centric view:
# both columns and --git-ignore, so ignored clutter disappears.
if (( $+commands[eza] )); then
  _eza='eza --group-directories-first --icons=auto'
  _eza_long="$_eza --long --header --group --octal-permissions --git --time-style=long-iso"
  alias ls="$_eza"
  alias l="$_eza_long --all"
  alias ll="$_eza_long"
  alias la="$_eza_long --all --git-repos"
  alias lg="$_eza_long --all --git-repos --git-ignore"
  alias lsa="$_eza_long --all"
  alias lt="$_eza --tree --level=2 --ignore-glob=.git"
  alias ltt="$_eza --tree --level=3 --ignore-glob=.git"
  unset _eza _eza_long
fi
