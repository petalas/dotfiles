#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

declare -a deps=(
    "7zip"
    "alacritty"
    "curl"
    "fd-find"
    "git"
    "grep"
    "iperf3"
    "neovim"
    "python3-venv"
    "python3"
    "ripgrep"
    "tar"
    "unzip"
    "wget"
    "zip"
    "zsh"
)

# MacOS dependencies managed by homebrew
if [[ $OSTYPE == "darwin"* ]]; then
    ./brew-deps.sh
fi

if [[ $OSTYPE == "linux"* ]]; then

    # for more recent neovim version
    sudo add-apt-repository ppa:neovim-ppa/unstable
    # for alacritty terminal
    sudo add-apt-repository ppa:aslatter/ppa -y

    echo "Updating apt..."
    sudo apt update
    echo "${green}Done.${reset}"

    for i in "${deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        sudo apt install $i -y
    done

    echo "${green}Done installing.${reset}"

    echo "Upgrading dependencies..."
    sudo apt upgrade -y && sudo apt autoremove -y
    echo "${green}Done upgrading.${reset}"
fi
