#!/usr/bin/env bash

install_ghostty() {
    local config_home os
    local installed=0

    os=$(dotfiles_os) || return 1
    if command -v ghostty >/dev/null 2>&1 ||
        { [[ "$os" == macos ]] && brew list --cask ghostty >/dev/null 2>&1; }; then
        installed=1
    fi

    if ((installed == 0)); then
        case "$os" in
            macos)
                brew install --cask ghostty
                ;;
            ubuntu|debian)
                if linux_package_available ghostty; then
                    linux_packages_install ghostty
                else
                    run_downloaded_script /bin/bash \
                        https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/6e93ad7bb4994e02c8fc18ab2e64c9d5ba8cece9/install.sh
                fi
                ;;
            arch) linux_packages_install ghostty ;;
            *) return 1 ;;
        esac
    fi

    if [[ "$os" != macos ]]; then
        config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
        mkdir -p "$config_home"
        printf '%s\n' com.mitchellh.ghostty.desktop >"$config_home/xdg-terminals.list"
    fi
}
