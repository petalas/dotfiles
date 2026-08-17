#!/usr/bin/env bash

install_node() {
    local os
    command -v node >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    case "$os" in
        macos) brew install node ;;
        ubuntu|debian|arch) linux_packages_install nodejs npm ;;
        *) return 1 ;;
    esac
}
