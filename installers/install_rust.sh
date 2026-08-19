#!/usr/bin/env bash

install_rust_operations() {
    printf '%s\t%s\n' rustup 'Ensure rustup'
    printf '%s\t%s\n' stable 'Ensure the stable Rust toolchain'
}

_install_rustup() {
    export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
    export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
    export PATH="$CARGO_HOME/bin:$PATH"

    if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
        echo "Installing rustup..."
        run_downloaded_script sh https://sh.rustup.rs \
            -y --no-modify-path --profile minimal --default-toolchain none || return 1
    fi
}

_install_rust_toolchain() {
    "$CARGO_HOME/bin/rustup" set profile default || return 1
    "$CARGO_HOME/bin/rustup" update stable || return 1
    "$CARGO_HOME/bin/rustup" default stable || return 1
    hash -r 2>/dev/null || true

    [[ "$(command -v rustc 2>/dev/null || true)" == "$CARGO_HOME/bin/rustc" ]] || {
        echo "The rustup-managed Rust compiler is not active" >&2
        return 1
    }
    [[ "$(command -v cargo 2>/dev/null || true)" == "$CARGO_HOME/bin/cargo" ]] || {
        echo "The rustup-managed Cargo executable is not active" >&2
        return 1
    }
}

install_rust() {
    run_installer_operation rustup 'Ensure rustup' _install_rustup || return 1
    run_installer_operation stable 'Ensure the stable Rust toolchain' _install_rust_toolchain
}
