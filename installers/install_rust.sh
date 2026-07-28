#!/usr/bin/env bash
# shellcheck disable=SC2154

install_rust() {
    command -v cargo >/dev/null 2>&1 && return 0
    case "$os_id" in
        macos) brew install rust ;;
        ubuntu|debian) linux_packages_install cargo rustc ;;
        arch) linux_packages_install rust ;;
        *) return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install rust" >&2
    exit 2
fi
