#!/usr/bin/env bash
set -e

# shellcheck source=lib/git-sync.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/git-sync.sh"

clone_or_ff https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" master
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone_or_ff https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/themes/powerlevel10k"
clone_or_ff https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_ff https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_ff https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
clone_or_ff https://github.com/TamCore/autoupdate-oh-my-zsh-plugins.git "$ZSH_CUSTOM/plugins/autoupdate"
