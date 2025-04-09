#!/usr/bin/env bash

# Color variables
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

# Install Docker function
install_docker() {
    # Check if Docker is already installed or if OS is not Linux
    if [[ $(which docker) == *"docker"* ]]; then
        echo "${green}Docker is already installed.${reset}"
        return 0
    fi

    echo "Installing ${yellow}Docker${reset}..."

    # Detect OS
    os_id=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

    # Create directory for keyrings if not exist
    sudo install -m 0755 -d /etc/apt/keyrings

    # Remove any existing Docker key
    sudo rm -f /etc/apt/keyrings/docker.gpg

    # Install Docker for Debian/Ubuntu
    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        curl -fsSL https://download.docker.com/linux/$os_id/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$os_id \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker "$(whoami)"
    elif [[ "$os_id" == "arch" ]]; then
        echo "Using ${yellow}paru${reset} to install Docker..."
        paru -S --noconfirm --needed docker docker-compose docker-buildx
        sudo usermod -aG docker "$(whoami)"
    else
        echo "Unsupported OS: $os_id"
        return 1
    fi

    echo "${green}Docker installation complete.${reset}"
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_docker
fi
