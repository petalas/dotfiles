#!/usr/bin/env bash

install_claude_code() {
    local os
    command -v claude >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    # The Brewfile's `claude-code` cask owns macOS installs; casks are
    # macOS-only, so elsewhere use the official native installer.
    if [[ "$os" == macos ]]; then
        brew install --cask claude-code
        return
    fi
    echo "Installing Claude Code..."
    run_downloaded_script bash https://claude.ai/install.sh
}
