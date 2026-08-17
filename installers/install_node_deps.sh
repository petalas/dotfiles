#!/usr/bin/env bash

_install_main_npm_batch() {
    npm install --global "$@" </dev/null
}

_install_scriptless_npm_batch() {
    npm install --global --ignore-scripts "$@" </dev/null
}

install_node_deps() {
    local install_failed=0
    local -a main_packages=(
        @openai/codex
        typescript
        typescript-language-server
    )

    command -v npm >/dev/null 2>&1 || return 1
    run_resilient_batch 'npm packages' _install_main_npm_batch \
        "${main_packages[@]}" || install_failed=1
    run_resilient_batch 'scriptless npm packages' _install_scriptless_npm_batch \
        @earendil-works/pi-coding-agent || install_failed=1
    return "$install_failed"
}
