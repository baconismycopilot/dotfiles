#!/usr/bin/env bash
# layout pip
#
# Create .venv with the active python, install requirements.txt, activate it,
# and warn if the venv's python does not match the version mise pins.
#
# Based on https://www.gbb.is/posts/2024-07-24-mise-direnv-and-python/
# Changes: `command -v`/grep instead of `which`/rg, Windows `Scripts/` layout.

layout_pip() {
    local PYTHON
    PYTHON="$(command -v python3 || command -v python || true)"
    if has mise; then
        PYTHON="$(mise which python 2>/dev/null || true)"
        [ -n "$PYTHON" ] || PYTHON="$(command -v python3 || command -v python || true)"
    fi

    if [ -z "$PYTHON" ]; then
        log_error "bin \`python\` not found"
        return 1
    fi

    VIRTUAL_ENV="$PWD/.venv"
    export VIRTUAL_ENV

    local REQ_TXT="${REQ_TXT:-requirements.txt}"
    if [ ! -f "$REQ_TXT" ]; then
        log_error "no \`$REQ_TXT\` found"
        log_status "creating a \`$REQ_TXT\`"
        touch "$REQ_TXT"
    fi

    watch_file "$REQ_TXT"

    local BIN="$VIRTUAL_ENV/bin"
    [ -d "$VIRTUAL_ENV/Scripts" ] && [ ! -d "$BIN" ] && BIN="$VIRTUAL_ENV/Scripts"

    if [ ! -d "$VIRTUAL_ENV" ]; then
        log_status "creating venv with \`python\`"
        "$PYTHON" -m venv "$VIRTUAL_ENV"
        [ -d "$VIRTUAL_ENV/Scripts" ] && [ ! -d "$VIRTUAL_ENV/bin" ] && BIN="$VIRTUAL_ENV/Scripts"

        log_status "installing requirements from \`$REQ_TXT\`"
        "$BIN/pip" install -r "$REQ_TXT"
    fi

    if has mise; then
        local venv_py
        venv_py="$("$BIN/python" -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
        if [ -n "$venv_py" ] && mise current python >/dev/null 2>&1; then
            mise current python | tr ' ' '\n' | grep -qxF "$venv_py" || \
                log_error "python venv version ($venv_py) and mise pin do not match"
        fi
    fi

    PATH_add "$BIN"
}
