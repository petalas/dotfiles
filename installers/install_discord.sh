#!/usr/bin/env bash

install_discord() {
    local os
    command -v discord >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    case "$os" in
        ubuntu|debian)
            linux_install_deb_url \
                'https://discord.com/api/download?platform=linux&format=deb' \
                discord
            ;;
        arch) linux_packages_install discord ;;
        *) return 1 ;;
    esac
}
