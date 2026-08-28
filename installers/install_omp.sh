#!/usr/bin/env bash

install_omp_operations() {
    printf '%s\t%s\n' package 'Install OMP package'
    printf '%s\t%s\n' dotfiles 'Link and configure OMP'
}

_install_omp_package() {
    if ! command -v omp >/dev/null 2>&1; then
        command -v bun >/dev/null 2>&1 || {
            echo "OMP installation requires Bun; install Bun first." >&2
            return 1
        }

        echo "Installing OMP..."
        bun install --global @oh-my-pi/pi-coding-agent </dev/null || return 1
        export PATH="$HOME/.bun/bin:$PATH"
        hash -r 2>/dev/null || true
    fi

    command -v omp >/dev/null 2>&1 || {
        echo "OMP was installed but is not available on PATH." >&2
        return 1
    }
}

_link_omp_dotfiles() {
    local root=${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
    "$root/link-dotfiles.sh" </dev/null
}

install_omp() {
    run_installer_operation package 'Install OMP package' _install_omp_package || return 1
    run_installer_operation dotfiles 'Link and configure OMP' _link_omp_dotfiles
}
