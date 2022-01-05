#!/bin/bash

if [ -d "$HOME/.oh-my-zsh" ]; then
	echo "Oh My Zsh is already installed, skipping."
else
	echo "Installing Oh My Zsh"
    echo "=====================IMPORTANT!====================="
    echo "Make sure to exit zsh once its installation is done!"
    echo "===================================================="
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

if [ -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]; then
	echo "Powerlevel10k is already installed, skipping."
else
	echo "Installing Powerlevel10k"
	git clone https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/themes/powerlevel10k
fi

if [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
	echo "zsh-autosuggestions is already installed, skipping."
else
	echo "Installing zsh-autosuggestions"
	git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi

if [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    echo "zsh-syntax-highlighting is already installed, skipping."
else
    echo "Installing zsh-syntax-highlighting"
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi