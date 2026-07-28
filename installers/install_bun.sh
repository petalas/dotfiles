#!/usr/bin/env bash

install_bun() {
    command -v bun >/dev/null 2>&1 && return 0
    if [[ "${os_id:-}" == arch ]]; then
        linux_packages_install bun
    else
        echo "Installing bun..."
        curl -fsSL https://bun.sh/install | bash
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_bun
fi 