#!/usr/bin/env bash
# use mise
#
# Load the mise tool environment (PATH, env vars) for this directory into direnv.
# Must be the FIRST command in .envrc so later layouts see mise-managed tools.
#
# Based on https://www.gbb.is/posts/2024-07-24-mise-direnv-and-python/ but
# uses `mise exec -- direnv dump` instead of the deprecated `mise direnv exec`
# (slated for removal in mise 2027.10.4). `mise exec` also installs any missing
# tools declared in mise.toml / .tool-versions on the way.

use_mise() {
    # mise's default install location is not always on PATH yet (fresh installs,
    # non-login shells, IDE terminals). Fall back to it before giving up.
    if ! has mise && [ -x "$HOME/.local/bin/mise" ]; then
        PATH_add "$HOME/.local/bin"
    fi

    if ! has mise; then
        log_error "bin \`mise\` not found (install: https://mise.jdx.dev/getting-started.html)"
        return 1
    fi

    # Reload when the tool pins change. The old `mise direnv` integration only
    # watched .tool-versions; watch the mise config files too.
    watch_file .tool-versions mise.toml .mise.toml mise.local.toml .mise.local.toml .config/mise/config.toml

    # Run `direnv dump` inside the mise environment and apply the result here.
    # "$direnv" is the direnv binary that is evaluating this .envrc.
    direnv_load mise exec -- "$direnv" dump

    # Report anything still missing (e.g. install failed offline).
    local missing
    missing="$(mise ls --current --missing 2>/dev/null || true)"
    if [ -n "$missing" ]; then
        log_error "mise: tools not installed, run \`mise install\`:"
        printf '%s\n' "$missing" | while IFS= read -r line; do log_error "  $line"; done
    fi
}
