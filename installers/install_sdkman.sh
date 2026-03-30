#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_sdkman() {
    if [[ ! -s "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh" ]]; then
        # SDKMAN requires Bash 4+; macOS ships with 3.2 but brew installs 5.x
        local brew_bash="/opt/homebrew/bin/bash"
        if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
            if [[ -x "$brew_bash" ]]; then
                echo "System bash is ${BASH_VERSION}, using brew bash for SDKMAN install..."
                curl -s https://get.sdkman.io | "$brew_bash"
                source "$HOME/.sdkman/bin/sdkman-init.sh"
                return
            else
                echo "${red}SDKMAN requires Bash 4+, current version is ${BASH_VERSION}.${reset}"
                echo "${yellow}On macOS, install modern bash first: brew install bash${reset}"
                return 1
            fi
        fi
        echo "Installing ${yellow}sdkman${reset}..."
        curl -s https://get.sdkman.io | bash
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    else
        source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_sdkman
fi
