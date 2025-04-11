#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_node() {
    os=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')
    if [[ ! $(which nvm) == *"nvm" ]]; then
        if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
            echo "Installing nvm..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
            source ~/.nvm/nvm.sh
        elif [[ "$os" == "arch" ]]; then
            yay -S --noconfirm nvm
        fi
    fi

    if [[ ! $(which node) == *"node" ]]; then
        echo "Installing node..."
        version=$(nvm ls-remote | grep Latest | tail -1 | awk '{print $1}')
        nvm install $version
        nvm alias default stable
        echo "Testing node installation, node -v --> $(node -v)"
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_node
fi 
