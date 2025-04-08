#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_zerotier() {
    if [ ! -f /usr/sbin/zerotier-one ]; then
        echo "Installing ${yellow}zerotier${reset}."
        curl -s https://install.zerotier.com | sudo bash
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_zerotier
fi 