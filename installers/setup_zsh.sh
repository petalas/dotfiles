#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

setup_zsh() {
    if [[ $OSTYPE == "msys"* ]]; then
        echo "${red}Cannot install ZSH on windows, please install it manually and run this script again.${reset}"
        return 1
    fi

    if [[ $SHELL == *"zsh" ]]; then
        echo "${green}Already using ZSH.${reset}"
        return 0
    fi

    if [[ $(which zsh) != *"zsh" ]]; then
        echo "Installing ${yellow}ZSH${reset} ..."
        
        # Detect OS
        os_id=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

        if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
            sudo apt update && sudo apt upgrade -y && sudo apt install zsh -y
        elif [[ "$os_id" == "arch" ]]; then
            paru -S --noconfirm --needed zsh
        elif [[ $OSTYPE == "darwin"* ]]; then
            brew install zsh
        else
            echo "${red}Unsupported OS: $os_id${reset}"
            return 1
        fi
    fi

    echo "Making ${yellow}ZSH${reset} the default shell."
    chsh -s $(which zsh)
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_zsh
fi 