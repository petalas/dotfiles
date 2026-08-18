#!/usr/bin/env bash

_install_cargo_batch() {
    cargo install --locked "$@"
}

install_rust_deps() {
    local os root platform_file _app _provider _role adapter package _option
    local -a packages=()
    root=${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
    os=$(dotfiles_os) || return 1
    platform_file="$root/catalog/platforms/$os.tsv"
    command -v cargo >/dev/null 2>&1 || return 1
    while IFS=$'\t' read -r _app _provider _role adapter package _option; do
        [[ "$adapter" == cargo-package ]] || continue
        packages+=("$package")
    done <"$platform_file"
    ((${#packages[@]} == 0)) || run_resilient_batch 'Cargo packages' _install_cargo_batch "${packages[@]}"
}
