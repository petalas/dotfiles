#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

function install_node() {
    if [[ ! $(which nvm) == *"nvm" ]]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
        source ~/.nvm/nvm.sh
    fi

    if [[ ! $(which node) == *"node" ]]; then
        echo "Installing node..."
        version=$(nvm ls-remote | grep Latest | tail -1 | awk '{print $1}')
        nvm install $version
        nvm alias default stable
        echo "Testing node installation, node -v --> $(node -v)"
    fi
}

function install_node_deps(){
    declare -a node_deps=("tree-sitter")
    for i in "${node_deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        npm i -g $i
    done
}


declare -a deps=(
    "7zip"
    "alacritty"
    "curl"
    "fd-find"
    "g++"
    "gcc"
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
    sudo add-apt-repository ppa:neovim-ppa/unstable -y
    # for alacritty terminal
    sudo add-apt-repository ppa:aslatter/ppa -y

    sudo apt update

    for i in "${deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        sudo apt install $i -y
    done
    echo "${green}Done installing.${reset}"

    echo "Upgrading dependencies..."
    sudo apt upgrade -y && sudo apt autoremove -y
    echo "${green}Done upgrading.${reset}"
fi

if [[ ! $OSTYPE == "msys"* ]]; then
    install_node
    install_node_deps
fi

