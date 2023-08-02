#!/bin/bash

if [[ $OSTYPE == "msys"* ]]; then
    echo "Cannot install neovim on windows, please run: winget install Neovim.Neovim"
    exit 1
fi

if [[ $OSTYPE == "linux"* ]]; then
    sudo add-apt-repository ppa:neovim-ppa/unstable
    sudo apt-get update
    sudo apt update && sudo apt install neovim -y
fi


if [[ $OSTYPE == "darwin"* ]]; then
    echo "neovim managed by brew, run ./setup-brew.sh"
fi