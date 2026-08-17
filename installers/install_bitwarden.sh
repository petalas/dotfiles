#!/usr/bin/env bash

install_bitwarden() {
    local os
    command -v bitwarden >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    case "$os" in
        ubuntu|debian)
            linux_install_deb_url \
                'https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb' \
                bitwarden
            ;;
        arch) linux_packages_install bitwarden ;;
        *) return 1 ;;
    esac
}
