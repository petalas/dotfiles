#!/usr/bin/env bash

install_vite_plus() {
    local vp_home="$HOME/.vite-plus"
    local vp_bin="$vp_home/bin/vp"
    if [[ ! -x "$vp_bin" ]]; then
        echo "Installing Vite+..."
        CI=true VP_HOME="$vp_home" VP_NODE_MANAGER=no VP_PM_MANAGER=no \
            run_downloaded_script bash https://viteplus.dev/install.sh </dev/null || return 1
    fi
    export VP_HOME="$vp_home"
    export PATH="$vp_home/bin:$PATH"
    hash -r 2>/dev/null || true
    [[ "$(command -v vp 2>/dev/null || true)" == "$vp_bin" ]] || {
        echo "The managed Vite+ executable is not active" >&2
        return 1
    }
}
