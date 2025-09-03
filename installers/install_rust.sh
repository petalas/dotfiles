#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_rust() {
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os="macos"
    elif [[ -f /etc/os-release ]]; then
        os=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')
    else
        echo ":: ${red}Unable to detect OS${reset}"
        return 1
    fi
    
    if ! command -v rustc || ! command -v cargo >/dev/null 2>&1 || ! command -v rustup >/dev/null 2>&1; then
        if [[ "$os" == "ubuntu" || "$os" == "debian" || "$os" == "macos" ]]; then
            echo
            echo ":: ${green}Installing rust...${reset}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        elif [[ "$os" == "arch" ]]; then
            sudo pacman -Sy --noconfirm rustup
            rustup default stable
        fi
        rustup component add rust-analyzer
        rustup component add rustfmt
    else
        echo ":: ${yellow}rust${reset} is ${green}already installed${reset}."
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust
fi 
