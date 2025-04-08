#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_lazygit() {
    if [[ $(which lazygit) == *"lazygit" ]]; then
        return 0
    fi

    # Detect OS
    os_id=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        echo "Installing ${yellow}lazygit${reset}..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm -f lazygit.tar.gz lazygit
        echo "Finished installing ${yellow}lazygit${reset}."
    elif [[ "$os_id" == "arch" ]]; then
        echo "Installing ${yellow}lazygit${reset}..."
        paru -S --noconfirm --needed lazygit
    else
        echo "Unsupported OS: $os_id"
        return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_lazygit
fi 