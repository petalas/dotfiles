#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_sdkman_deps() {
    local failed=0
    declare -a sdkman_deps=("java" "kotlin" "gradle")
    for i in "${sdkman_deps[@]}"; do
        if ! command -v "$i" >/dev/null 2>&1; then
            echo "Installing ${yellow}$i${reset}"
            if ! sdk install "$i"; then
                failed=1
            fi
        fi
    done

    return "$failed"
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_sdkman_deps
fi 
