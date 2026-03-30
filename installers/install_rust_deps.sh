#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_rust_deps() {
    echo "Updating rustup"
    rustup update

    local installed
    installed=$(cargo install --list)

    declare -a rust_deps=("tree-sitter-cli" "ripgrep" "wasm-bindgen-cli" "cargo-edit" "tealdeer")
    for i in "${rust_deps[@]}"; do
        if echo "$installed" | grep -q "^$i "; then
            echo "${green}$i${reset} is already installed."
        else
            echo "Installing ${yellow}$i${reset}"
            cargo install --locked "$i"
        fi
    done

    # yazi requires yazi-build instead of direct cargo install
    if echo "$installed" | grep -q "^yazi-fm "; then
        echo "${green}yazi${reset} is already installed."
    else
        echo "Installing ${yellow}yazi${reset}"
        cargo install --locked yazi-build
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust_deps
fi
