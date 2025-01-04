#!/usr/bin/env bash

if [[ $OSTYPE == "msys"* ]]; then
    echo "Cannot install ZSH on windows, please install it manually and run this script again." # TODO
    exit 1
fi

if [[ $SHELL == *"zsh" ]]; then
    echo "Already using ZSH."
    exit 1
fi

if [[ $(which zsh) != *"zsh" ]]; then
    echo "Installing ZSH."
    if [[ $OSTYPE == "darwin"* ]]; then
        brew install zsh
    fi
    if [[ $OSTYPE == "linux"* ]]; then
        sudo apt update && sudo apt upgrade -y && sudo apt install zsh -y
    fi
fi

echo "Making ZSH the default shell."
sudo chsh -s $(which zsh)
