#!/bin/bash

if [[ $OSTYPE == "msys"* ]]; then
    echo "Cannot install ZSH on windows, please install it manually and run this script again." # TODO
    exit 1
fi

if [[ $SHELL == *"zsh" ]]; then
    echo "Already using ZSH."
else
    if [[ $(which zsh) == *"zsh" ]]; then
        echo "$(which zsh) found, making it the default shell..."
        chsh -s $(which zsh)
    else
        if [[ $OSTYPE == "darwin"* ]]; then
            echo "Installing ZSH."
            brew install zsh && chsh -s $(which zsh)
        fi
        if [[ $OSTYPE == "linux"* ]]; then
            echo "Installing ZSH."
            sudo apt update && sudo apt upgrade -y && sudo apt install zsh -y && chsh -s $(which zsh)
        fi
    fi
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh is already installed, skipping."
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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

./link-dotfiles.sh

exec zsh