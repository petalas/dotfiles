#!/usr/bin/env bash

install_opencode() {
    local opencode_bin="$HOME/.opencode/bin/opencode"
    if [[ ! -x "$opencode_bin" ]]; then
        echo "Installing OpenCode..."
        # dot/zshrc already puts ~/.opencode/bin on PATH; the installer must not
        # append to the symlinked shell profiles.
        run_downloaded_script bash https://opencode.ai/v2/install --no-modify-path </dev/null || return 1
    fi
}
