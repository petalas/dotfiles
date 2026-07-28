#!/usr/bin/env bash

install_rust_deps() {
    local entry binary package
    local -a packages=(
        tree-sitter:tree-sitter-cli
        rg:ripgrep
        wasm-bindgen:wasm-bindgen-cli
        cargo-add:cargo-edit
        tldr:tealdeer
        bat:bat
        watchexec:watchexec-cli
    )

    command -v cargo >/dev/null 2>&1 || return 1
    for entry in "${packages[@]}"; do
        binary=${entry%%:*}
        package=${entry#*:}
        if command -v "$binary" >/dev/null 2>&1 ||
            [[ -x "$HOME/.local/bin/$binary" ]]; then
            continue
        fi
        echo "Installing/updating $package"
        cargo install --locked "$package" || return 1
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install rust_deps" >&2
    exit 2
fi
