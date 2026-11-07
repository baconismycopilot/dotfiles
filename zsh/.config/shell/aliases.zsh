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
