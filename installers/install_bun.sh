#!/usr/bin/env bash

install_bun() {
    local bun_bin="$HOME/.bun/bin/bun"
    local os
    os=$(dotfiles_os) || return 1
    if [[ "$os" == arch ]]; then
        command -v bun >/dev/null 2>&1 && return 0
        linux_packages_install bun
    else
        if [[ ! -x "$bun_bin" ]]; then
            echo "Installing bun..."
            run_downloaded_script bash https://bun.sh/install || return 1
        fi
        export PATH="$HOME/.bun/bin:$PATH"
        hash -r 2>/dev/null || true
        [[ "$(command -v bun 2>/dev/null || true)" == "$bun_bin" ]] || {
            echo "The managed Bun executable is not active" >&2
            return 1
        }
    fi
}
