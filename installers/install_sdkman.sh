#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_sdkman() {
    if [[ ! -s $SDKMAN_DIR/bin/sdkman-init.sh ]]; then
        echo "Installing ${yellow}sdkman${reset}..."
        curl -s https://get.sdkman.io | bash
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    else
        echo "${yellow}sdkman${reset} is already installed, updating it..."
        source "$HOME/.sdkman/bin/sdkman-init.sh" # need to source it again for some reason otherwise 'sdk command not found'
        sdk selfupdate force
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_sdkman
fi 