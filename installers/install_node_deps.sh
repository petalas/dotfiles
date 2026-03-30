#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_node_deps() {
    if ! type npm &>/dev/null; then
        echo "npm is not installed. Please install node first. (${yellow}install_node.sh${reset} should have been called first.)"
        return 1
    fi

    declare -a node_deps=("@anthropic-ai/claude-code" "@openai/codex" "typescript" "typescript-language-server")
    for i in "${node_deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        npm i -g $i
    done
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_node_deps
fi 