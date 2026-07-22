#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_rust_deps() {
    echo "Updating rustup"
    rustup update || return 1

    declare -a rust_deps=("tree-sitter-cli" "ripgrep" "wasm-bindgen-cli" "cargo-edit" "tealdeer" "bat" "watchexec-cli")
    for i in "${rust_deps[@]}"; do
        # Cargo skips recompilation when the latest compatible release is
        # already installed and upgrades when crates.io has a newer one.
        echo "Installing/updating ${yellow}$i${reset}"
        cargo install --locked "$i" || return 1
    done
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust_deps
fi
