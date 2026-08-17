#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../lib/platform.sh
source "$DOTFILES_ROOT/lib/platform.sh"
# shellcheck source=../lib/download.sh
source "$DOTFILES_ROOT/lib/download.sh"
# shellcheck source=../lib/packages.sh
source "$DOTFILES_ROOT/lib/packages.sh"

for script in "$SCRIPT_DIR"/install_*.sh "$SCRIPT_DIR"/setup_*.sh; do
    # shellcheck disable=SC1090
    source "$script"
done

list_installers() {
    printf '%s\n' \
        'Available installers:' \
        '  Applications:' \
        '    bitwarden  chrome       code       discord   docker' \
        '    ghostty    herdr        lazydocker lazygit   neovim' \
        '    obsidian   yazi' \
        '  Toolchains and add-ons:' \
        '    bun         node         node_deps  rust      rust_deps' \
        '    claude_code' \
        '  System setup:' \
        '    audio       locale       ssh_keys   zsh'
}
