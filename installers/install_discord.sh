#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_discord() {
    if [[ ($(which discord) == *"discord") || (! $OSTYPE == "linux"*) ]]; then
        echo "${green}discord${reset} is already installed."
        return 1
    fi
    echo "Installing ${yellow}discord${reset} ..."
    wget -q 'https://discord.com/api/download?platform=linux&format=deb' -O /tmp/discord_amd64.deb
    sudo dpkg -i /tmp/discord_amd64.deb
    sudo rm -f /tmp/discord_amd64.deb
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_discord
fi 