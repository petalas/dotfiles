#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh

if ! declare -F sdkman_current_bash_is_compatible >/dev/null 2>&1; then
    # shellcheck source=install_sdkman.sh
    source "$(dirname "${BASH_SOURCE[0]}")/install_sdkman.sh"
fi

install_sdkman_deps() {
    local sdkman_bash sdkman_dir
    local failed=0
    sdkman_dir="${SDKMAN_DIR:-$HOME/.sdkman}"

    if ! sdkman_current_bash_is_compatible; then
        if ! sdkman_bash=$(sdkman_compatible_bash); then
            echo "${red}SDKMAN packages require Bash 4+, current version is ${BASH_VERSION}.${reset}"
            return 1
        fi
        "$sdkman_bash" "${BASH_SOURCE[0]}"
        return
    fi

    if ! type sdk >/dev/null 2>&1; then
        if [[ ! -s "$sdkman_dir/bin/sdkman-init.sh" ]]; then
            echo "${red}SDKMAN is not installed; cannot install SDKMAN packages.${reset}"
            return 1
        fi
        # shellcheck disable=SC1090
        source "$sdkman_dir/bin/sdkman-init.sh"
    fi

    declare -a sdkman_deps=("java" "kotlin" "gradle")
    for i in "${sdkman_deps[@]}"; do
        if ! command -v "$i" >/dev/null 2>&1; then
            echo "Installing ${yellow}$i${reset}"
            # Override older SDKMAN configs that otherwise ask whether a newly
            # installed candidate should become the default.
            if ! sdkman_auto_answer=true sdk install "$i" </dev/null; then
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
