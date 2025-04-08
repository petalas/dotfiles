#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_code() {
    if [[ $(which code) == *"code" ]]; then
        echo "${green}visual studio code${reset} is already installed."
        return 0
    fi

    # Detect OS
    os_id=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        echo "Installing ${yellow}visual studio code${reset} ..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        rm -f packages.microsoft.gpg
        sudo apt update
        sudo apt install code -yq
    elif [[ "$os_id" == "arch" ]]; then
        echo "Installing ${yellow}visual studio code${reset} ..."
        paru -S --noconfirm --needed code
    else
        echo "Unsupported OS: $os_id"
        return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_code
fi 