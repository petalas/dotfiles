#!/usr/bin/env bash
# shellcheck disable=SC2154

install_node() {
    command -v node >/dev/null 2>&1 && return 0
    case "$os_id" in
        macos) brew install node ;;
        ubuntu|debian|arch) linux_packages_install nodejs npm ;;
        *) return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install node" >&2
    exit 2
fi
