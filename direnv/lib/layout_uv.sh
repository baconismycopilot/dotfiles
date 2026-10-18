#!/usr/bin/env bash
# layout uv
#
# Make sure uv has installed the required interpreter, created .venv, synced
# dependencies, and then put the venv on PATH (equivalent of `activate`).
# Creates a pyproject.toml with `uv init` if the project has none.
#
# Based on https://www.gbb.is/posts/2024-07-24-mise-direnv-and-python/#layout_uvsh
# Changes: `command -v` instead of `which`, Windows `Scripts/` venv layout,
# watch pyproject/lock/.python-version so direnv re-syncs when they change.

layout_uv() {
    local UV
    UV="$(command -v uv || true)"
    if has mise; then
        UV="$(mise which uv 2>/dev/null || true)"
        [ -n "$UV" ] || UV="$(command -v uv || true)"
    fi

    if [ -z "$UV" ]; then
        log_error "bin \`uv\` not found (add \`uv = \"latest\"\` to mise.toml and run \`mise install\`)"
        return 1
    fi

    VIRTUAL_ENV="${UV_PROJECT_ENVIRONMENT:-$PWD/.venv}"
    export VIRTUAL_ENV
    export UV_PROJECT_ENVIRONMENT="$VIRTUAL_ENV"

    local PYPROJECT_TOML="${PYPROJECT_TOML:-pyproject.toml}"
    if [ ! -f "$PYPROJECT_TOML" ]; then
        log_error "no \`$PYPROJECT_TOML\` found"
        log_status "creating a \`$PYPROJECT_TOML\` with \`uv\`"
        "$UV" init
    fi

    watch_file "$PYPROJECT_TOML" uv.lock .python-version

    if [ ! -d "$VIRTUAL_ENV" ]; then
        log_status "installing python interpreter with \`uv\`"
        "$UV" python install -q
        log_status "creating venv with \`uv\`"
        "$UV" venv "$VIRTUAL_ENV" -q
    fi

    log_status "syncing venv with \`uv\`"
    "$UV" sync

    # POSIX venvs use bin/, Windows (Git Bash / MSYS2) venvs use Scripts/.
    if [ -d "$VIRTUAL_ENV/Scripts" ] && [ ! -d "$VIRTUAL_ENV/bin" ]; then
        PATH_add "$VIRTUAL_ENV/Scripts"
    else
        PATH_add "$VIRTUAL_ENV/bin"
    fi
}
