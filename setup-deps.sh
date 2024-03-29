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

install_node_deps() {
    declare -a node_deps=("typescript" "typescript-language-server")
    for i in "${node_deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        npm i -g $i
    done
}

install_lazydocker() {
    if [[ ($(which lazydocker) == *"lazydocker") || (! $OSTYPE == "linux"*) ]]; then
        return 1
    fi
    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
}

install_lazygit() {
    if [[ ($(which lazygit) == *"lazygit") || (! $OSTYPE == "linux"*) ]]; then
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

install_sdkman() {
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

install_sdkman_deps() {
    declare -a sdkman_deps=("java" "kotlin" "gradle")
    for i in "${sdkman_deps[@]}"; do
        if [[ ! $(which $i) == *"$i" ]]; then
            echo "Installing ${yellow}$i${reset}"
            sdk install $i
        fi
    done
}

install_rust() {
    if [[ ! $(which cargo) == *"cargo" ]]; then
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source "$HOME/.cargo/env"
        rustup toolchain install nightly
    fi
}

install_rust_deps() {
    echo "Updating rustup"
    rustup update
    declare -a rust_deps=("tree-sitter-cli" "ripgrep" "wasm-bindgen-cli")
    for i in "${rust_deps[@]}"; do
        if [[ ! $(which $i) == *"$i" ]]; then
            echo "Installing ${yellow}$i${reset}"
            cargo install $i
        fi
    done
}

# In WSL2 add this to /etc/wsl.conf to enable systemd before installing
# [boot]
# systemd=true
install_zerotier() {
    if [ ! -f /usr/sbin/zerotier-one ]; then
        echo "Installing ${yellow}zerotier${reset}."
        curl -s https://install.zerotier.com | sudo bash
    fi
}

install_docker() {
    if [[ ($(which docker) == *"docker") || (! $OSTYPE == "linux"*) ]]; then
        return 1
    fi
    echo "Installing ${yellow}docker${reset}."

    sudo install -m 0755 -d /etc/apt/keyrings

    # avoid prompt: File '/etc/apt/keyrings/docker.gpg' exists. Overwrite? (y/N)
    sudo rm -f /etc/apt/keyrings/docker.gpg

    if [[ $(cat /etc/os-release | grep ID) == *"ubuntu" ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
            "deb [arch="$(dpkg --print-architecture)" \
        signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
            sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    else
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
            "deb [arch="$(dpkg --print-architecture)" \
        signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
            sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    fi

    sudo apt update
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y -q
    sudo /usr/sbin/usermod -aG docker "$(whoami)"
}

declare -a deps=(
    "7zip"
    "alacritty"
    "bc"
    "build-essential"
    "ca-certificates"
    "cmake"
    "curl"
    "dnsutils"
    "fd-find"
    "g++"
    "gcc"
    "git"
    "gnupg"
    "grep"
    "htop"
    "iperf3"
    "neovim"
    "nmap"
    "pass"
    "python3-venv"
    "python3"
    "ssh"
    "sshpass"
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

    # avoid add-apt-repository: command not found
    sudo apt update && sudo apt install software-properties-common -y

    # for more recent neovim version
    sudo add-apt-repository ppa:neovim-ppa/unstable -y
    # for alacritty terminal
    sudo add-apt-repository ppa:aslatter/ppa -y

    sudo apt update

    for i in "${deps[@]}"; do
        echo "Installing ${yellow}$i${reset}"
        sudo DEBIAN_FRONTEND=noninteractive apt install $i -y -q
    done
    echo "${green}Done installing.${reset}"

    echo "Upgrading dependencies..."
    sudo apt upgrade -y && sudo apt autoremove -y
    echo "${green}Done upgrading.${reset}"

    install_lazydocker # handled by brew for MacOS
    install_lazygit    # handled by brew for MacOS
    install_zerotier   # handled by brew for MacOS
fi

# same for Ubuntu and MacOS
if [[ ! $OSTYPE == "msys"* ]]; then
    install_node
    install_node_deps
    install_sdkman
    install_sdkman_deps
    install_rust
    install_rust_deps
    install_docker
fi
