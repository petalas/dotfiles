#!/usr/bin/env bash
# shellcheck disable=SC2154

install_discord() {
    command -v discord >/dev/null 2>&1 && return 0
    case "$os_id" in
        ubuntu|debian)
            linux_install_deb_url \
                'https://discord.com/api/download?platform=linux&format=deb' \
                discord
            ;;
        arch) linux_packages_install discord ;;
        *) return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install discord" >&2
    exit 2
fi
