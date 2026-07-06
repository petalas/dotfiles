#!/usr/bin/env bash

install_herdr() {
    if ! command -v herdr >/dev/null 2>&1; then
        echo "Installing herdr..."
        curl -fsSL https://herdr.dev/install.sh | sh || return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_herdr
fi
