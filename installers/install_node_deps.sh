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
        # Vite+'s npm shim prompts before exposing each global binary when
        # stdin is a TTY. With stdin closed it follows its documented
        # non-interactive path and creates the link automatically.
        if [[ "$i" == "@anthropic-ai/claude-code" ]]; then
            # npm 12 blocks lifecycle scripts unless each trusted package is
            # explicitly allowed. Claude Code's postinstall installs its
            # platform-native binary, so a scriptless install is unusable.
            if ! npm install --global --allow-scripts="$i" "$i" </dev/null; then
                failed=1
            fi
        elif ! npm install --global "$i" </dev/null; then
            failed=1
        fi
    done

    echo "Installing ${yellow}@earendil-works/pi-coding-agent${reset}"
    if ! npm install --global --ignore-scripts @earendil-works/pi-coding-agent </dev/null; then
        failed=1
    fi

    return "$failed"
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_node_deps
fi 
