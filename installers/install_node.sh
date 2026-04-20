#!/usr/bin/env bash

install_node() {
    if [[ $OSTYPE == "darwin"* ]]; then
        # On macOS, nvm is installed via Homebrew — source it into the current session
        export NVM_DIR="$HOME/.nvm"
        [ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"
    else
        os=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')
        if ! type nvm &>/dev/null; then
            if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
                # Fetch latest nvm tag dynamically. grep instead of jq so we
                # don't depend on jq being installed on a fresh box.
                nvm_version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest \
                    | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
                nvm_version="${nvm_version:-v0.40.3}"
                echo "Installing nvm ${nvm_version}..."
                curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
                source ~/.nvm/nvm.sh
            elif [[ "$os" == "arch" ]]; then
                paru -S --noconfirm nvm
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
