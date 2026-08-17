#!/usr/bin/env bash
# Platform and privilege helpers shared by Bash setup scripts and Zsh updates.

# Print the supported platform identifier: macos, ubuntu, debian, or arch.
dotfiles_os() {
    local os_name distribution
    if [[ -n "${DOTFILES_OS_OVERRIDE:-}" ]]; then
        case "$DOTFILES_OS_OVERRIDE" in
            macos|ubuntu|debian|arch) printf '%s\n' "$DOTFILES_OS_OVERRIDE" ;;
            *) return 1 ;;
        esac
        return 0
    fi
    os_name=$(uname -s)
    if [[ "$os_name" == Darwin ]]; then
        printf 'macos\n'
        return 0
    fi
    if [[ "$os_name" != Linux || ! -r /etc/os-release ]]; then
        return 1
    fi

    distribution=$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release)
    [[ "$distribution" != archarm ]] || distribution=arch
    case "$distribution" in
        ubuntu|debian|arch) printf '%s\n' "$distribution" ;;
        *) return 1 ;;
    esac
}

dotfiles_os_raw() {
    local distribution
    if [[ -n "${DOTFILES_OS_RAW_OVERRIDE:-}" ]]; then
        printf '%s\n' "$DOTFILES_OS_RAW_OVERRIDE"
        return 0
    fi
    if [[ $(uname -s) == Darwin ]]; then
        printf 'macos\n'
        return 0
    fi
    [[ -r /etc/os-release ]] || return 1
    distribution=$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release)
    printf '%s\n' "$distribution"
}

dotfiles_os_codename() {
    if [[ -n "${DOTFILES_OS_CODENAME_OVERRIDE:-}" ]]; then
        printf '%s\n' "$DOTFILES_OS_CODENAME_OVERRIDE"
        return 0
    fi
    [[ -r /etc/os-release ]] || return 1
    awk -F= '$1 == "VERSION_CODENAME" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release
}

run_as_root() {
    if [[ "${DOTFILES_PACKAGE_NO_SUDO:-0}" == 1 || "${EUID:-$(id -u)}" == 0 ]]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

require_noninteractive_root() {
    if [[ "${EUID:-$(id -u)}" == 0 ]]; then
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
        echo "Unattended setup requires working 'sudo -n'." >&2
        return 1
    fi
}
