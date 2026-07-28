#!/usr/bin/env bash
# shellcheck disable=SC2154

install_ghostty() {
    local script config_home
    if command -v ghostty >/dev/null 2>&1 ||
        { [[ "$os_id" == macos ]] && brew list --cask ghostty >/dev/null 2>&1; }; then
        return 0
    fi

    case "$os_id" in
        macos)
            brew install --cask ghostty
            ;;
        ubuntu|debian)
            if linux_package_available ghostty; then
                linux_packages_install ghostty
            else
                script=$(mktemp "${TMPDIR:-/tmp}/ghostty-install.XXXXXX")
                curl -fsSL \
                    https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh \
                    -o "$script" || { rm -f "$script"; return 1; }
                /bin/bash "$script" || { rm -f "$script"; return 1; }
                rm -f "$script"
            fi
            ;;
        arch) linux_packages_install ghostty ;;
        *) return 1 ;;
    esac

    if [[ "$os_id" != macos ]]; then
        config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
        mkdir -p "$config_home"
        printf '%s\n' com.mitchellh.ghostty.desktop >"$config_home/xdg-terminals.list"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install ghostty" >&2
    exit 2
fi
