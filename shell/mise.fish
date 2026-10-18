# Symlinked to ~/.config/fish/conf.d/mise.fish by install.sh (auto-loaded).
# See shell/mise.sh for the rationale: direnv drives mise, no `mise activate`.

fish_add_path --global --move "$HOME/.local/bin"

set -l mise_data (set -q MISE_DATA_DIR; and echo $MISE_DATA_DIR; or echo (set -q XDG_DATA_HOME; and echo $XDG_DATA_HOME; or echo "$HOME/.local/share")/mise)
if test -d "$mise_data/shims"
    fish_add_path --global --move "$mise_data/shims"
end

if type -q direnv
    direnv hook fish | source
end
