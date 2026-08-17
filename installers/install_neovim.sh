#!/usr/bin/env bash

install_neovim() {
    local os
    command -v nvim >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    case "$os" in
        macos) brew install neovim ;;
        ubuntu|debian|arch) linux_packages_install neovim ;;
        *) return 1 ;;
    esac
}
