#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib/git-sync.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/git-sync.sh"

clone_or_ff_with_nested \
    https://github.com/ohmyzsh/ohmyzsh.git \
    "$HOME/.oh-my-zsh" \
    master \
    themes/powerlevel10k \
    https://github.com/romkatv/powerlevel10k.git
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone_or_ff https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/themes/powerlevel10k"
clone_or_ff https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_ff https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
