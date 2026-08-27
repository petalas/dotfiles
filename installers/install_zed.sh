#!/usr/bin/env bash

_zed_release_asset() {
    case "$1" in
        x86_64) printf 'zed-linux-x86_64.tar.gz\n' ;;
        aarch64|arm64) printf 'zed-linux-aarch64.tar.gz\n' ;;
        *)
            printf 'Unsupported Zed architecture: %s\n' "$1" >&2
            return 1
            ;;
    esac
}

_zed_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        shasum -a 256 "$1" | awk '{ print $1 }'
    fi
}

_install_zed_release() (
    local asset metadata record url expected actual entries entry
    local archive staging destination backup desktop_source desktop_staged

    asset=$(_zed_release_asset "$(uname -m)") || return 1
    metadata=$(download_stdout https://api.github.com/repos/zed-industries/zed/releases/latest) || return 1
    record=$(printf '%s' "$metadata" | jq -er --arg asset "$asset" '
        .assets[] |
        select(.name == $asset and (.browser_download_url | type == "string") and
            (.digest | type == "string") and (.digest | startswith("sha256:"))) |
        [.browser_download_url, (.digest | sub("^sha256:"; ""))] | @tsv
    ') || return 1
    IFS=$'\t' read -r url expected <<<"$record" || return 1
    [[ "$url" == https://github.com/zed-industries/zed/releases/download/*/"$asset" ]] || return 1
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || return 1

    archive=$(mktemp "${TMPDIR:-/tmp}/dotfiles-zed.XXXXXX.tar.gz") || return 1
    staging=''
    backup=''
    trap 'rm -f "$archive"; [[ -z "$staging" ]] || rm -rf "$staging"; [[ -z "$backup" ]] || rm -rf "$backup"' EXIT
    download_file "$url" "$archive" || return 1
    actual=$(_zed_sha256 "$archive") || return 1
    actual=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]') || return 1
    expected=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]') || return 1
    [[ "$actual" == "$expected" ]] || {
        printf 'Checksum mismatch for %s\nExpected: %s\nActual:   %s\n' "$asset" "$expected" "$actual" >&2
        return 1
    }

    entries=$(tar -tzf "$archive") || return 1
    while IFS= read -r entry; do
        case "$entry" in
            zed.app|zed.app/*) ;;
            *)
                printf 'Unexpected path in Zed archive: %s\n' "$entry" >&2
                return 1
                ;;
        esac
        case "/$entry/" in
            *'/../'*|*'/./'*)
                printf 'Unsafe path in Zed archive: %s\n' "$entry" >&2
                return 1
                ;;
        esac
    done <<<"$entries"

    mkdir -p "$HOME/.local" || return 1
    staging=$(mktemp -d "$HOME/.local/.zed-release.XXXXXX") || return 1
    tar -xzf "$archive" -C "$staging" || return 1
    [[ -x "$staging/zed.app/bin/zed" ]] || return 1
    "$staging/zed.app/bin/zed" --version >/dev/null || return 1

    desktop_source="$staging/zed.app/share/applications/dev.zed.Zed.desktop"
    desktop_staged="$staging/dev.zed.Zed.desktop"
    [[ -f "$desktop_source" ]] || return 1
    sed \
        -e "s|Icon=zed|Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png|g" \
        -e "s|Exec=zed|Exec=$HOME/.local/zed.app/bin/zed|g" \
        "$desktop_source" >"$desktop_staged" || return 1

    destination="$HOME/.local/zed.app"
    if [[ -e "$destination" || -L "$destination" ]]; then
        backup=$(mktemp -d "$HOME/.local/.zed-backup.XXXXXX") || return 1
        rmdir "$backup" || return 1
        if ! mv "$destination" "$backup"; then
            backup=''
            return 1
        fi
    fi
    if ! mv "$staging/zed.app" "$destination"; then
        if [[ -n "$backup" ]] && ! mv "$backup" "$destination"; then
            printf 'Previous Zed installation remains at %s\n' "$backup" >&2
            backup=''
        else
            backup=''
        fi
        return 1
    fi

    if ! mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" ||
        ! ln -sfn "$destination/bin/zed" "$HOME/.local/bin/zed" ||
        [[ ! -L "$HOME/.local/bin/zed" ]] ||
        [[ "$(readlink "$HOME/.local/bin/zed")" != "$destination/bin/zed" ]] ||
        ! mv -f "$desktop_staged" "$HOME/.local/share/applications/dev.zed.Zed.desktop"; then
        rm -rf "$destination"
        if [[ -n "$backup" ]] && ! mv "$backup" "$destination"; then
            printf 'Previous Zed installation remains at %s\n' "$backup" >&2
            backup=''
        else
            backup=''
        fi
        return 1
    fi
    if [[ -n "$backup" ]]; then
        rm -rf "$backup" || return 1
    fi
    backup=''
)

install_zed() {
    local os
    os=$(dotfiles_os) || return 1
    case "$os" in
        debian|ubuntu) ;;
        *)
            printf 'The direct Zed installer is unsupported on %s\n' "$os" >&2
            return 1
            ;;
    esac

    echo "Installing/updating Zed..."
    _install_zed_release || return 1
    export PATH="$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null || true
    [[ "$(command -v zed 2>/dev/null || true)" == "$HOME/.local/bin/zed" ]] || {
        echo "The managed Zed executable is not active" >&2
        return 1
    }
}
