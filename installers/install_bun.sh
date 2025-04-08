#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_bun() {
    if [[ ! $(which bun) == *"bun" ]]; then
        echo "Installing bun..."
        curl -fsSL https://bun.sh/install | bash
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_bun
fi 