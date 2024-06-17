#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)


install_code() {
    if [[ ($(which code) == *"code") || (! $OSTYPE == "linux"*) ]]; then
        echo "${green}visual studio code${reset} is already installed."
        return 1
    fi
    echo "Installing ${yellow}visual studio code${reset} ..."
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
	echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
	rm -f packages.microsoft.gpg
	sudo apt update
	sudo apt install code -yq
}

install_bitwarden() {
    if [[ ($(which bitwarden) == *"bitwarden") || (! $OSTYPE == "linux"*) ]]; then
        echo "${green}bitwarden${reset} is already installed."
        return 1
    fi
    echo "Installing ${yellow}bitwarden${reset} ..."
    wget -q 'https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb' -O /tmp/bitwarden_amd64.deb
    sudo dpkg -i /tmp/bitwarden_amd64.deb
    sudo rm -f /tmp/bitwarden_amd64.deb
}

install_discord() {
    if [[ ($(which discord) == *"discord") || (! $OSTYPE == "linux"*) ]]; then
        echo "${green}discord${reset} is already installed."
        return 1
    fi
    echo "Installing ${yellow}discord${reset} ..."
    wget -q 'https://discord.com/api/download?platform=linux&format=deb' -O /tmp/discord_amd64.deb
    sudo dpkg -i /tmp/discord_amd64.deb
    sudo rm -f /tmp/discord_amd64.deb
}

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
        # rustup toolchain install nightly
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

# use Alsa / pulseaudio
# how to force pair device through CLI if having issues: https://askubuntu.com/a/1411988
setup_audio() {
    if [[ (! $OSTYPE == "linux"*) ]]; then
        return 1
    fi
    sudo apt install pulseaudio libasound2 libasound2-plugins libasound2-doc alsa-utils alsa-oss alsamixergui apulse alsa-firmware-loaders pulseaudio-module-bluetooth -yq
    sudo alsactl init
    sudo systemctl restart bluetooth.service
    bluetoothctl power off && bluetoothctl power on
}

declare -a deps=(
    "7zip"
    "alacritty"
    "apt-transport-https"
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
    "gpg"
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
    "tldr"
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

    setup_audio

    # these should be handled by brew for MacOS
    install_lazydocker
    install_lazygit
    install_zerotier
    install_code
    install_bitwarden
    install_discord
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
