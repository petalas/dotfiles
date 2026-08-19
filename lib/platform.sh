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

dotfiles_target_user() {
    printf '%s\n' "${SUDO_USER:-$(id -un)}"
}

dotfiles_login_shell() {
    local login_shell os user
    user=${1:-$(dotfiles_target_user)}
    os=$(dotfiles_os) || return 1
    if [[ "$os" == macos ]]; then
        login_shell=$(dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{ print $2 }')
    else
        login_shell=$(getent passwd "$user" | cut -d: -f7)
    fi
    [[ -n "$login_shell" ]] || return 1
    printf '%s\n' "$login_shell"
}

run_as_root() {
    if [[ "${DOTFILES_PACKAGE_NO_SUDO:-0}" == 1 || "${EUID:-$(id -u)}" == 0 ]]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

configure_passwordless_sudo() {
    local legacy_sudoers_target sudoers_source sudoers_target user_id
    if [[ "${EUID:-$(id -u)}" == 0 ]]; then
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        echo "sudo is required to configure administrator access." >&2
        return 1
    fi

    user_id=$(id -u)
    [[ "$user_id" =~ ^[0-9]+$ ]] || {
        echo "Could not determine the numeric user ID for sudoers." >&2
        return 1
    }
    sudoers_source=$(mktemp "${TMPDIR:-/tmp}/dotfiles-sudoers.XXXXXX") || return 1
    sudoers_target=/etc/sudoers.d/zz-dotfiles-$user_id
    legacy_sudoers_target=/etc/sudoers.d/dotfiles-$user_id
    {
        echo '# Managed by dotfiles easy-install.sh.'
        printf '\\#%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user_id"
    } >"$sudoers_source"
    chmod 0600 "$sudoers_source"

    echo "Configuring passwordless sudo (your sudo password may be requested once)..."
    if ! sudo sh -c '
        set -eu
        source_file=$1
        target=$2
        legacy_target=$3
        staging=${target}.tmp
        previous=${target}.previous
        had_previous=0
        changed=0
        committed=0
        cleanup() {
            rm -f "$staging"
            if [ "$changed" -eq 1 ] && [ "$committed" -eq 0 ]; then
                rm -f "$target"
                if [ "$had_previous" -eq 1 ] && [ -e "$previous" ]; then
                    mv "$previous" "$target"
                fi
            fi
            rm -f "$previous"
        }
        trap cleanup EXIT HUP INT TERM
        command -v visudo >/dev/null 2>&1
        install -d -m 0750 "$(dirname "$target")"
        install -o root -g root -m 0440 "$source_file" "$staging"
        visudo -cf "$staging" >/dev/null
        if [ -e "$target" ]; then
            mv "$target" "$previous"
            had_previous=1
        fi
        changed=1
        mv "$staging" "$target"
        visudo -cf /etc/sudoers >/dev/null
        committed=1
        rm -f "$previous"
        if [ "$legacy_target" != "$target" ]; then rm -f "$legacy_target"; fi
        trap - EXIT HUP INT TERM
    ' sh "$sudoers_source" "$sudoers_target" "$legacy_sudoers_target"; then
        rm -f "$sudoers_source"
        echo "Could not configure passwordless sudo; administrator access is required." >&2
        return 1
    fi
    rm -f "$sudoers_source"

    sudo -k
    if ! sudo -n true 2>/dev/null; then
        echo "Passwordless sudo was installed but could not be verified." >&2
        return 1
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
