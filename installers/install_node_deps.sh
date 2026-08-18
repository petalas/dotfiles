#!/usr/bin/env bash

_install_main_npm_batch() {
    npm install --global "$@" </dev/null
}

_install_scriptless_npm_batch() {
    npm install --global --ignore-scripts "$@" </dev/null
}

install_node_deps() {
    local install_failed=0 os root platform_file _app adapter package option
    local -a main_packages=() scriptless_packages=()
    root=${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
    os=$(dotfiles_os) || return 1
    platform_file="$root/catalog/platforms/$os.tsv"
    command -v npm >/dev/null 2>&1 || return 1
    while IFS=$'\t' read -r _app adapter package option; do
        [[ "$adapter" == npm-package ]] || continue
        if [[ "$option" == ignore-scripts ]]; then scriptless_packages+=("$package")
        else main_packages+=("$package")
        fi
    done <"$platform_file"
    ((${#main_packages[@]} == 0)) ||
        run_resilient_batch 'npm packages' _install_main_npm_batch "${main_packages[@]}" || install_failed=1
    ((${#scriptless_packages[@]} == 0)) ||
        run_resilient_batch 'scriptless npm packages' _install_scriptless_npm_batch \
            "${scriptless_packages[@]}" || install_failed=1
    return "$install_failed"
}
