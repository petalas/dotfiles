#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh

sdkman_current_bash_is_compatible() {
    ((BASH_VERSINFO[0] >= 4))
}

sdkman_bash_path_is_compatible() {
    local candidate="$1"
    [[ -x "$candidate" ]] &&
        "$candidate" --noprofile --norc -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null
}

sdkman_compatible_bash() {
    local candidate brew_prefix

    if sdkman_current_bash_is_compatible; then
        printf '%s\n' "${BASH:-bash}"
        return 0
    fi

    if command -v brew >/dev/null 2>&1 &&
        brew_prefix=$(brew --prefix bash 2>/dev/null); then
        candidate="$brew_prefix/bin/bash"
        if sdkman_bash_path_is_compatible "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if sdkman_bash_path_is_compatible "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

install_sdkman() {
    local sdkman_bash sdkman_dir
    sdkman_dir="${SDKMAN_DIR:-$HOME/.sdkman}"

    if ! sdkman_bash=$(sdkman_compatible_bash); then
        echo "${red}SDKMAN requires Bash 4+, current version is ${BASH_VERSION}.${reset}"
        echo "${yellow}On macOS, install modern bash first: brew install bash${reset}"
        return 1
    fi

    if [[ ! -s "$sdkman_dir/bin/sdkman-init.sh" ]]; then
        if ! sdkman_current_bash_is_compatible; then
            echo "System bash is ${BASH_VERSION}, using $sdkman_bash for SDKMAN install..."
        fi
        echo "Installing ${yellow}sdkman${reset}..."
        curl -fsSL https://get.sdkman.io | "$sdkman_bash" || return 1
    fi

    # Never source SDKMAN back into Apple's Bash 3. Its current path helpers
    # use Bash 4's ${name^^} expansion, which is a fatal expansion error.
    # install_sdkman_deps launches a Bash 4+ subprocess for the SDK installs.
    if sdkman_current_bash_is_compatible; then
        # shellcheck disable=SC1090
        source "$sdkman_dir/bin/sdkman-init.sh"
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_sdkman
fi
