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
        echo "Installing ZSH."
        if [[ $OSTYPE == "darwin"* ]]; then
            brew install zsh
        fi
        if [[ $OSTYPE == "linux"* ]]; then
            sudo apt update && sudo apt upgrade -y && sudo apt install zsh -y
        fi
        echo "Making ZSH the default shell."
        chsh -s $(which zsh)
    fi
fi

# Install .oh-my-zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh is already installed, skipping."
else
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# theme for oh-my-zsh
if [ -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]; then
    echo "Powerlevel10k is already installed, skipping."
else
    echo "Installing Powerlevel10k..."
    git clone https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/themes/powerlevel10k
fi

# plugins
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom" # zshrc has not been sourced at this stage

if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "zsh-autosuggestions is already installed, skipping."
else
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
fi

if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "zsh-syntax-highlighting is already installed, skipping."
else
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
fi

if [ -d "$ZSH_CUSTOM/plugins/autoupdate" ]; then
    echo "autoupdate is already installed, skipping."
else
    echo "Installing autoupdate..."
    git clone https://github.com/TamCore/autoupdate-oh-my-zsh-plugins $ZSH_CUSTOM/plugins/autoupdate
fi
