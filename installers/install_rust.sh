#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_rust() {
    if [[ ! $(which cargo) == *"cargo" ]]; then
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source "$HOME/.cargo/env"
        rustup component add rust-analyzer
        rustup component add rustfmt
        # rustup toolchain install nightly
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust
fi 