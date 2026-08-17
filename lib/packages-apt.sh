#!/usr/bin/env bash
# Debian/Ubuntu APT and apt-fast helpers.

_linux_apt_get() {
    _linux_as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
        apt-get "$@"
}

_linux_preseed_apt_fast() {
    local connections="${DOTFILES_APT_PARALLEL_DOWNLOADS:-8}"

    _require_positive_integer DOTFILES_APT_PARALLEL_DOWNLOADS "$connections" || return 1
    command -v debconf-set-selections >/dev/null 2>&1 || return 1
    printf '%s\n' \
        "debconf apt-fast/maxdownloads string $connections" \
        'debconf apt-fast/dlflag boolean true' \
        'debconf apt-fast/aptmanager string apt-get' |
        _linux_as_root debconf-set-selections
}

_linux_install_apt_fast_prerequisites() {
    local -a packages=()

    command -v curl >/dev/null 2>&1 || packages+=(ca-certificates curl)
    command -v gpg >/dev/null 2>&1 || packages+=(gnupg)
    command -v debconf-set-selections >/dev/null 2>&1 || packages+=(debconf)
    ((${#packages[@]} == 0)) && return 0

    _linux_apt_get update && _linux_apt_get install -y "${packages[@]}"
}

_linux_write_apt_fast_source() {
    local suite="$1"
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local key_file="${DOTFILES_APT_FAST_KEYRING:-$apt_root/keyrings/apt-fast.gpg}"
    local source_file="${DOTFILES_APT_FAST_SOURCE:-$apt_root/sources.list.d/apt-fast.sources}"
    local work_file

    case "$suite" in
        ''|*[!a-zA-Z0-9._-]*)
            echo "Invalid apt-fast suite: $suite" >&2
            return 1
            ;;
    esac
    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-fast-source.XXXXXX")
    cat >"$work_file" <<EOF
Types: deb
URIs: ${DOTFILES_APT_FAST_PPA_URI:-https://ppa.launchpadcontent.net/apt-fast/stable/ubuntu/}
Suites: $suite
Components: main
Signed-By: $key_file
EOF
    if ! _linux_install_root_file "$work_file" "$source_file"; then
        rm -f "$work_file"
        return 1
    fi
    rm -f "$work_file"
}

_linux_install_apt_fast_key() {
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local key_file="${DOTFILES_APT_FAST_KEYRING:-$apt_root/keyrings/apt-fast.gpg}"
    local fingerprint="BC5934FD3DEBD4DAEA544F791E2824A7F22B44BD"
    local armored_file work_file

    armored_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-fast-key-armored.XXXXXX") || return 1
    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-fast-key.XXXXXX") || {
        rm -f "$armored_file"
        return 1
    }
    if ! download_file \
        'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBC5934FD3DEBD4DAEA544F791E2824A7F22B44BD' \
        "$armored_file" ||
        ! verify_key_fingerprint "$armored_file" "$fingerprint" ||
        ! gpg --dearmor <"$armored_file" >"$work_file" || [[ ! -s "$work_file" ]]; then
        rm -f "$armored_file" "$work_file"
        return 1
    fi
    rm -f "$armored_file"
    if ! _linux_install_root_file "$work_file" "$key_file"; then
        rm -f "$work_file"
        return 1
    fi
    rm -f "$work_file"
}

_linux_install_apt_fast() {
    local distribution current_suite suite tried_suites="" repository_ready=0
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local source_file="${DOTFILES_APT_FAST_SOURCE:-$apt_root/sources.list.d/apt-fast.sources}"
    local -a suites=()

    _linux_install_apt_fast_prerequisites || return 1
    _linux_install_apt_fast_key || return 1

    distribution=$(linux_distribution)
    if [[ -n "${DOTFILES_APT_FAST_SUITE:-}" ]]; then
        suites=("$DOTFILES_APT_FAST_SUITE")
    elif [[ "$distribution" == ubuntu ]]; then
        current_suite=$(_linux_debian_release)
        suites=("$current_suite" jammy focal)
    else
        suites=(jammy focal)
    fi

    for suite in "${suites[@]}"; do
        [[ -n "$suite" && " $tried_suites " != *" $suite "* ]] || continue
        tried_suites="$tried_suites $suite"
        _linux_write_apt_fast_source "$suite" || continue
        if _linux_apt_get update; then
            repository_ready=1
            break
        fi
    done
    if ((repository_ready == 0)); then
        _linux_as_root rm -f "$source_file"
        _linux_apt_get update || true
        return 1
    fi

    _linux_preseed_apt_fast || return 1
    _linux_apt_get install -y apt-fast aria2 || return 1
    command -v apt-fast >/dev/null 2>&1
}

_linux_configure_apt_fast() {
    local config_file="${DOTFILES_APT_FAST_CONFIG:-/etc/apt-fast.conf}"
    local connections="${DOTFILES_APT_PARALLEL_DOWNLOADS:-8}"
    local work_file

    [[ -f "$config_file" ]] || return 0
    _require_positive_integer DOTFILES_APT_PARALLEL_DOWNLOADS "$connections" || return 1
    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-fast.XXXXXX")
    awk -v connections="$connections" '
        BEGIN { maxnum = 0; per_server = 0 }
        /^[[:space:]]*#?[[:space:]]*_MAXNUM=/ {
            if (!maxnum++) print "_MAXNUM=" connections
            next
        }
        /^[[:space:]]*#?[[:space:]]*_MAXCONPERSRV=/ {
            if (!per_server++) print "_MAXCONPERSRV=" connections
            next
        }
        { print }
        END {
            if (!maxnum) print "_MAXNUM=" connections
            if (!per_server) print "_MAXCONPERSRV=" connections
        }
    ' "$config_file" >"$work_file"

    if _linux_files_differ "$config_file" "$work_file" &&
        ! _linux_install_root_file "$work_file" "$config_file"; then
        rm -f "$work_file"
        return 1
    fi
    rm -f "$work_file"
}

_linux_bootstrap_apt_frontend() {
    local frontend=""

    if [[ "${DOTFILES_SKIP_APT_FAST_DETECTION:-0}" != 1 ]] &&
        command -v apt-fast >/dev/null 2>&1; then
        _linux_preseed_apt_fast || return 1
        frontend=apt-fast
    elif _linux_install_apt_fast; then
        frontend=apt-fast
    elif command -v nala >/dev/null 2>&1; then
        frontend=nala
    else
        echo "Warning: apt-fast setup failed; trying Nala from the distro repository." >&2
        _linux_apt_get update || true
        if apt-cache show nala >/dev/null 2>&1; then
            _linux_apt_get install -y nala || true
            command -v nala >/dev/null 2>&1 && frontend=nala
        fi
    fi

    if [[ -z "$frontend" ]]; then
        echo "Warning: no parallel APT frontend is available; using apt-get." >&2
        frontend=apt-get
    fi
    _dotfiles_apt_frontend="$frontend"
    [[ "$frontend" != apt-fast ]] || _linux_configure_apt_fast
}

