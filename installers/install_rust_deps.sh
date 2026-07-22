#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_rust_deps() {
    local failed=0

    echo "Updating rustup"
    if ! rustup update; then
        failed=1
    fi

    declare -a rust_deps=("tree-sitter-cli" "ripgrep" "wasm-bindgen-cli" "cargo-edit" "tealdeer" "bat" "watchexec-cli")
    for i in "${rust_deps[@]}"; do
        # Cargo skips recompilation when the latest compatible release is
        # already installed and upgrades when crates.io has a newer one.
        echo "Installing/updating ${yellow}$i${reset}"
        if ! cargo install --locked "$i"; then
            failed=1
        fi
    done

    return "$failed"
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust_deps
fi
