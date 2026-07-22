#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_node_deps() {
    local failed=0

    if ! type npm &>/dev/null; then
        echo "npm is not installed. Please install node first. (${yellow}install_node.sh${reset} should have been called first.)"
        return 1
    fi

    declare -a node_deps=("@anthropic-ai/claude-code" "@openai/codex" "typescript" "typescript-language-server")
    for i in "${node_deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        if ! npm i -g "$i"; then
            failed=1
        fi
    done

    echo "Installing ${yellow}@earendil-works/pi-coding-agent${reset}"
    if ! npm i -g --ignore-scripts @earendil-works/pi-coding-agent; then
        failed=1
    fi

    return "$failed"
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_node_deps
fi 
