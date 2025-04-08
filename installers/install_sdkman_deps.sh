#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_sdkman_deps() {
    declare -a sdkman_deps=("java" "kotlin" "gradle")
    for i in "${sdkman_deps[@]}"; do
        if [[ ! $(which $i) == *"$i" ]]; then
            echo "Installing ${yellow}$i${reset}"
            sdk install $i
        fi
    done
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_sdkman_deps
fi 