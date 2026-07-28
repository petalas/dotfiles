#!/usr/bin/env bash
# shellcheck disable=SC2154

install_neovim() {
    case "$os_id" in
        macos) brew install neovim ;;
        ubuntu|debian|arch) linux_packages_install neovim ;;
        *) return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install neovim" >&2
    exit 2
fi
