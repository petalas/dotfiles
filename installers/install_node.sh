#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_node() {
    if [[ $OSTYPE == "darwin"* ]]; then
        # On macOS, nvm is installed via Homebrew — source it into the current session
        export NVM_DIR="$HOME/.nvm"
        [ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"
    else
        os=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')
        if ! type nvm &>/dev/null; then
            if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
                echo "Installing nvm..."
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
                source ~/.nvm/nvm.sh
            elif [[ "$os" == "arch" ]]; then
                yay -S --noconfirm nvm
            fi
        fi
    fi

    if ! type node &>/dev/null; then
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
