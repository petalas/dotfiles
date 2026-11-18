#!/usr/bin/env bash

# Keep this pin identical to TLC_TOOL in the statechart skill's scripts/run.ts.
# TLA2TOOLS bypasses that skill's own checksum, so this is the only check.
TLA2TOOLS_VERSION=1.7.4
TLA2TOOLS_SHA256=936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
TLA2TOOLS_URL="https://github.com/tlaplus/tlaplus/releases/download/v$TLA2TOOLS_VERSION/tla2tools.jar"
TLA2TOOLS_MAX_BYTES=134217728

_tla2tools_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        shasum -a 256 "$1" | awk '{ print $1 }'
    fi
}

_tla2tools_jar_is_pinned() {
    local actual
    [[ -f "$1" ]] || return 1
    actual=$(_tla2tools_sha256 "$1") || return 1
    [[ "$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')" == "$TLA2TOOLS_SHA256" ]]
}

_tla2tools_wrapper() {
    cat <<EOF
#!/bin/sh
# Managed by dotfiles install_tla2tools. Usage: tla2tools tlc2.TLC Spec.tla
jar="\${TLA2TOOLS:-\$HOME/.local/share/tla2tools/tla2tools.jar}"
case "\${1:-}" in
    --version) echo "tla2tools $TLA2TOOLS_VERSION"; exit 0 ;;
    ''|-h|--help) echo "Usage: tla2tools <main-class> [args...]  (e.g. tlc2.TLC, tla2sany.SANY)" >&2; exit 2 ;;
esac
exec "\${JAVA:-java}" -cp "\$jar" "\$@"
EOF
}

_install_tla2tools_jar() (
    local jar=$1 staged actual
    staged=$(mktemp "$(dirname "$jar")/.tla2tools.XXXXXX") || return 1
    trap 'rm -f "$staged"' EXIT
    download_file "$TLA2TOOLS_URL" "$staged" "$TLA2TOOLS_MAX_BYTES" || return 1
    actual=$(_tla2tools_sha256 "$staged") || return 1
    actual=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')
    [[ "$actual" == "$TLA2TOOLS_SHA256" ]] || {
        printf 'Checksum mismatch for tla2tools.jar %s\nExpected: %s\nActual:   %s\n' \
            "$TLA2TOOLS_VERSION" "$TLA2TOOLS_SHA256" "$actual" >&2
        return 1
    }
    chmod 0644 "$staged" && mv -f "$staged" "$jar"
)

install_tla2tools() {
    local share_dir="$HOME/.local/share/tla2tools" bin_dir="$HOME/.local/bin"
    local jar="$share_dir/tla2tools.jar" wrapper="$bin_dir/tla2tools" staged

    mkdir -p "$share_dir" "$bin_dir" || return 1
    if ! _tla2tools_jar_is_pinned "$jar"; then
        echo "Installing tla2tools $TLA2TOOLS_VERSION..."
        _install_tla2tools_jar "$jar" || return 1
    fi

    if [[ ! -x "$wrapper" || "$(cat "$wrapper")" != "$(_tla2tools_wrapper)" ]]; then
        staged=$(mktemp "$bin_dir/.tla2tools.XXXXXX") || return 1
        if ! _tla2tools_wrapper >"$staged" || ! chmod 0755 "$staged" || ! mv -f "$staged" "$wrapper"; then
            rm -f "$staged"
            return 1
        fi
    fi

    export TLA2TOOLS="$jar"
    export PATH="$bin_dir:$PATH"
    hash -r 2>/dev/null || true
    [[ "$(command -v tla2tools 2>/dev/null || true)" == "$wrapper" ]] || {
        echo "The managed tla2tools wrapper is not active" >&2
        return 1
    }
}
