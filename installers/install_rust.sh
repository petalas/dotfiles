#!/usr/bin/env bash

install_rust() {
    local os
    command -v cargo >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    case "$os" in
        macos) brew install rust ;;
        ubuntu|debian) linux_packages_install cargo rustc ;;
        arch) linux_packages_install rust ;;
        *) return 1 ;;
    esac
}
