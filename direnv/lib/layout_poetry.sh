#!/usr/bin/env bash
# layout poetry
#
# Ensure poetry has a venv with dependencies installed, activate it, and warn
# if the venv's python does not match the version mise pins.
#
# Based on https://www.gbb.is/posts/2024-07-24-mise-direnv-and-python/
# Changes: `command -v`/grep instead of `which`/rg, Windows `Scripts/` layout.

layout_poetry() {
    local POETRY
    POETRY="$(command -v poetry || true)"
    if has mise; then
        POETRY="$(mise which poetry 2>/dev/null || true)"
        [ -n "$POETRY" ] || POETRY="$(command -v poetry || true)"
    fi

    if [ -z "$POETRY" ]; then
        log_error "bin \`poetry\` not found"
        return 1
    fi

    local PYPROJECT_TOML="${PYPROJECT_TOML:-pyproject.toml}"
    if [ ! -f "$PYPROJECT_TOML" ]; then
        log_error "no \`$PYPROJECT_TOML\` found"
        log_status "creating a \`$PYPROJECT_TOML\` with \`poetry\`"
        touch README.md
        "$POETRY" init -q
        "$POETRY" install --no-root
    fi

    watch_file "$PYPROJECT_TOML" poetry.lock

    if [ -d ".venv" ]; then
        VIRTUAL_ENV="$PWD/.venv"
    else
        VIRTUAL_ENV="$("$POETRY" env list --full-path 2>/dev/null | head -1 | awk '{print $1}')"
    fi

    if [ -z "$VIRTUAL_ENV" ] || [ ! -d "$VIRTUAL_ENV" ]; then
        log_status "creating venv with \`poetry\`"
        "$POETRY" install
        VIRTUAL_ENV="$("$POETRY" env list --full-path | head -1 | awk '{print $1}')"
    fi

    if has mise; then
        local venv_py
        venv_py="$("$POETRY" run python -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
        if [ -n "$venv_py" ] && mise current python >/dev/null 2>&1; then
            mise current python | tr ' ' '\n' | grep -qxF "$venv_py" || \
                log_error "python venv version ($venv_py) and mise pin do not match"
        fi
    fi

    log_status "running poetry check"
    "$POETRY" check --ansi >/dev/null || true

    if [ -d "$VIRTUAL_ENV/Scripts" ] && [ ! -d "$VIRTUAL_ENV/bin" ]; then
        PATH_add "$VIRTUAL_ENV/Scripts"
    else
        PATH_add "$VIRTUAL_ENV/bin"
    fi
    export POETRY_ACTIVE=1
    export VIRTUAL_ENV
}
