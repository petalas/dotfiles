#!/usr/bin/env bash

install_bun() {
    if ! command -v bun >/dev/null 2>&1; then
        echo "Installing bun..."
        curl -fsSL https://bun.sh/install | bash
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_bun
fi 