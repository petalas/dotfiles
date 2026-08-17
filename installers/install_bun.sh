#!/usr/bin/env bash

install_bun() {
    local os
    command -v bun >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    if [[ "$os" == arch ]]; then
        linux_packages_install bun
    else
        echo "Installing bun..."
        run_downloaded_script bash https://bun.sh/install
    fi
}
