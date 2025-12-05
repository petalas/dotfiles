#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_rust_deps() {
    echo "Updating rustup"
    rustup update
    declare -a rust_deps=("tree-sitter-cli" "ripgrep" "wasm-bindgen-cli" "cargo-edit" "yazi-fm" "yazi-cli" "tealdeer")
    for i in "${rust_deps[@]}"; do
        if [[ ! $(which $i) == *"$i" ]]; then
            echo "Installing ${yellow}$i${reset}"
            cargo install --locked $i
        fi
    done
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust_deps
fi 