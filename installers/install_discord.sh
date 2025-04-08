#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_discord() {
    if [[ $(which discord) == *"discord" ]]; then
        echo "${green}discord${reset} is already installed."
        return 0
    fi

    # Detect OS
    os_id=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        echo "Installing ${yellow}discord${reset} ..."
        wget -q 'https://discord.com/api/download?platform=linux&format=deb' -O /tmp/discord_amd64.deb
        sudo dpkg -i /tmp/discord_amd64.deb
        sudo rm -f /tmp/discord_amd64.deb
     elif [[ "$os_id" == "arch" ]]; then
        echo "Installing ${yellow}discord${reset} ..."
        paru -S --noconfirm --needed discord
    else
        echo "Unsupported OS: $os_id"
        return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_discord
fi 