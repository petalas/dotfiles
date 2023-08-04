#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

declare -a deps=(
    "7zip"
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

# TODO: refactor
if [[ $OSTYPE == "linux"* ]]; then
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