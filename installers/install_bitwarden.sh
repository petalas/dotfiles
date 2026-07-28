#!/usr/bin/env bash
# shellcheck disable=SC2154

install_bitwarden() {
    command -v bitwarden >/dev/null 2>&1 && return 0
    case "$os_id" in
        ubuntu|debian)
            linux_install_deb_url \
                'https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb' \
                bitwarden
            ;;
        arch) linux_packages_install bitwarden ;;
        *) return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install bitwarden" >&2
    exit 2
fi
