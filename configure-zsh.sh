#!/usr/bin/env bash

# shellcheck source=lib/git-sync.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/git-sync.sh"

# Install .oh-my-zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
	echo "Oh My Zsh is already installed, skipping."
else
	echo "Installing Oh My Zsh..."
	_install_oh_my_zsh() {
		local installer
		# This branch started without an installation, so an incomplete checkout
		# from a previous attempt is ours to remove before retrying.
		rm -rf "$HOME/.oh-my-zsh"
		installer=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) || return 1
		sh -c "$installer" "" --unattended
	}
	_git_retry "installing Oh My Zsh" _install_oh_my_zsh
	unset -f _install_oh_my_zsh
fi

# Theme + plugins: clone if missing, otherwise fast-forward (see lib/git-sync.sh).
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom" # zshrc has not been sourced at this stage

clone_or_ff https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/themes/powerlevel10k"
clone_or_ff https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_ff https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_ff https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
clone_or_ff https://github.com/TamCore/autoupdate-oh-my-zsh-plugins "$ZSH_CUSTOM/plugins/autoupdate"
