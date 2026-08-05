#!/usr/bin/env bash

install_claude_code() {
    command -v claude >/dev/null 2>&1 && return 0
    # The Brewfile's `claude-code` cask owns macOS installs; casks are
    # macOS-only, so elsewhere use the official native installer.
    if [[ "${os_id:-}" == macos ]]; then
        brew install --cask claude-code
        return
    fi
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_claude_code
fi
