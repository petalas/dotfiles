#!/usr/bin/env bash

setup_homebrew() {
    local brew_bin profile shellenv_line

    if command -v brew >/dev/null 2>&1; then
        brew_bin=$(command -v brew)
        echo "Homebrew is already installed."
    else
        echo "Installing Homebrew..."
        NONINTERACTIVE=1 run_downloaded_script /bin/bash \
            https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh || return 1
        if [[ -x /opt/homebrew/bin/brew ]]; then
            brew_bin=/opt/homebrew/bin/brew
        elif [[ -x /usr/local/bin/brew ]]; then
            brew_bin=/usr/local/bin/brew
        else
            echo "Homebrew installation did not produce a brew executable." >&2
            return 1
        fi
    fi

    eval "$("$brew_bin" shellenv)"
    profile="$HOME/.zprofile"
    shellenv_line="eval \"\$($brew_bin shellenv)\""
    touch "$profile"
    grep -Fqx "$shellenv_line" "$profile" || printf '%s\n' "$shellenv_line" >>"$profile"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    # shellcheck source=lib/download.sh
    source "$root_dir/lib/download.sh"
    setup_homebrew
fi
