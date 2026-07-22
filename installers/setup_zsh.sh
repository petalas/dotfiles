#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


setup_zsh() {
    if [[ $OSTYPE == "msys"* ]]; then
        echo "${red}Cannot install ZSH on windows, please install it manually and run this script again.${reset}"
        return 1
    fi

    if [[ $SHELL == *"zsh" ]]; then
        echo "${green}Already using ZSH.${reset}"
        return 0
    fi

    if [[ "${DOTFILES_INTEGRATION_TEST:-0}" == "1" ]] && command -v zsh >/dev/null 2>&1; then
        echo "ZSH is installed; skipping the login-shell change in the container integration profile."
        return 0
    fi

    if ! command -v zsh >/dev/null 2>&1; then
        echo "Installing ${yellow}ZSH${reset} ..."
        

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
    if [[ $OSTYPE == "darwin"* ]]; then
        # easy-install configures passwordless sudo before reaching this point;
        # change the login shell without triggering chsh's password prompt.
        sudo chsh -s "$(command -v zsh)" "$(whoami)"
    else
        chsh -s "$(command -v zsh)"
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_zsh
fi 
