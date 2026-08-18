#!/usr/bin/env bash
# Small, checked download helpers. Callers remain responsible for cleanup.

_download_validate_settings() {
    local name value
    for name in DOTFILES_DOWNLOAD_RETRIES DOTFILES_CONNECT_TIMEOUT DOTFILES_DOWNLOAD_TIMEOUT; do
        case "$name" in
            DOTFILES_DOWNLOAD_RETRIES) value="${DOTFILES_DOWNLOAD_RETRIES:-3}" ;;
            DOTFILES_CONNECT_TIMEOUT) value="${DOTFILES_CONNECT_TIMEOUT:-15}" ;;
            DOTFILES_DOWNLOAD_TIMEOUT) value="${DOTFILES_DOWNLOAD_TIMEOUT:-600}" ;;
        esac
        case "$value" in
            ''|*[!0-9]*|0)
                printf '%s must be a positive integer: %s\n' "$name" "$value" >&2
                return 1
                ;;
        esac
    done
}

download_file() {
    local url="$1"
    local destination="$2"

    _download_validate_settings || return 1
    if ! curl --fail --location --silent --show-error \
        --retry "${DOTFILES_DOWNLOAD_RETRIES:-3}" \
        --connect-timeout "${DOTFILES_CONNECT_TIMEOUT:-15}" \
        --max-time "${DOTFILES_DOWNLOAD_TIMEOUT:-600}" \
        "$url" -o "$destination"; then
        rm -f "$destination"
        return 1
    fi
    if [[ ! -s "$destination" ]]; then
        rm -f "$destination"
        echo "Downloaded file is empty: $url" >&2
        return 1
    fi
}

download_stdout() {
    _download_validate_settings || return 1
    curl --fail --location --silent --show-error \
        --retry "${DOTFILES_DOWNLOAD_RETRIES:-3}" \
        --connect-timeout "${DOTFILES_CONNECT_TIMEOUT:-15}" \
        --max-time "${DOTFILES_DOWNLOAD_TIMEOUT:-600}" \
        "$1"
}

run_downloaded_script() {
    local interpreter="$1"
    local url="$2"
    local script_file result=0
    shift 2

    script_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-installer.XXXXXX") || return 1
    if ! download_file "$url" "$script_file"; then
        rm -f "$script_file"
        return 1
    fi
    "$interpreter" "$script_file" "$@" || result=$?
    rm -f "$script_file"
    return "$result"
}

github_latest_tag() {
    local repository="$1"
    local tag

    tag=$(download_stdout "https://api.github.com/repos/$repository/releases/latest" |
        jq -er '.tag_name | select(type == "string" and length > 0)') || return 1
    printf '%s\n' "$tag"
}

verify_sha256_manifest() {
    local file="$1"
    local manifest_url="$2"
    local asset_name="$3"
    local expected actual manifest

    manifest=$(mktemp "${TMPDIR:-/tmp}/dotfiles-checksums.XXXXXX") || return 1
    if ! download_file "$manifest_url" "$manifest"; then
        rm -f "$manifest"
        return 1
    fi
    expected=$(awk -v name="$asset_name" '$NF == name || $NF == "*" name { print $1; exit }' "$manifest")
    rm -f "$manifest"
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || {
        echo "Checksum for $asset_name was not found in $manifest_url" >&2
        return 1
    }
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file" | awk '{ print $1 }')
    else
        actual=$(shasum -a 256 "$file" | awk '{ print $1 }')
    fi
    actual=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')
    expected=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')
    [[ "$actual" == "$expected" ]] || {
        printf 'Checksum mismatch for %s\nExpected: %s\nActual:   %s\n' \
            "$asset_name" "$expected" "$actual" >&2
        return 1
    }
}

verify_key_fingerprint() {
    local key_file="$1"
    local expected="$2"
    local actual

    actual=$(gpg --show-keys --with-colons "$key_file" 2>/dev/null |
        awk -F: '$1 == "fpr" { print $10; exit }') || return 1
    if [[ "$actual" != "$expected" ]]; then
        printf 'Unexpected signing-key fingerprint in %s\nExpected: %s\nActual:   %s\n' \
            "$key_file" "$expected" "${actual:-missing}" >&2
        return 1
    fi
}
