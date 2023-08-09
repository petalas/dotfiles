#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_node() {
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

install_node_deps(){
    declare -a node_deps=("tree-sitter")
    for i in "${node_deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        npm i -g $i
    done
}

install_lazydocker() {
      if [[ ( $(which lazydocker) == *"lazydocker") || ( ! $OSTYPE == "linux"* ) ]]; then
        return 1
    fi
    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
}

install_lazygit(){
    if [[ ( $(which lazygit) == *"lazygit") || ( ! $OSTYPE == "linux"* ) ]]; then
        return 1
    fi
    echo "Installing ${yellow}lazygit${reset}..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit /usr/local/bin
    rm -f lazygit.tar.gz lazygit
    echo "Finished installing ${yellow}lazygit${reset}."
}

install_sdkman(){
    if [[ ! -s $SDKMAN_DIR/bin/sdkman-init.sh ]]; then
        echo "Installing ${yellow}sdkman${reset}..."
        curl -s https://get.sdkman.io | bash
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    else
        echo "${yellow}sdkman${reset} is already installed, updating it..."
        source "$HOME/.sdkman/bin/sdkman-init.sh" # need to source it again for some reason otherwise 'sdk command not found'
        sdk selfupdate force
    fi
}

install_sdkman_deps(){
    declare -a sdkman_deps=("java" "kotlin" "gradle")
    for i in "${sdkman_deps[@]}"; do
        if [[ !  $(which $i) == *"$i" ]]; then
            echo "Installing ${yellow}$i${reset}"
            sdk install $i
        fi
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
    "python3"
    "python3-venv"
    "ripgrep"
    "ssh"
    "tar"
    "unzip"
    "wget"
    "xdg-utils"
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

    install_lazydocker  # handled by brew for MacOS
    install_lazygit     # handled by brew for MacOS
fi

# same for Ubuntu and MacOS
if [[ ! $OSTYPE == "msys"* ]]; then
    install_node
    install_node_deps
    install_sdkman
    install_sdkman_deps
fi

