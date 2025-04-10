#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_rust() {
    os=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')
    if ! command -v cargo >/dev/null 2>&1 || ! command -v rustup >/dev/null 2>&1; then
        if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
            echo
            echo ":: ${green}Intalling rust...${reset}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        elif [[ "$os" == "arch" ]]; then
            sudo pacman -Sy --noconfirm rust rustup
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
