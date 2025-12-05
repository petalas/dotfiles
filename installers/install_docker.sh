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
    version_codename=$(grep -w VERSION_CODENAME /etc/os-release | cut -d '=' -f 2 | tr -d '"')

    # Install Docker for Debian/Ubuntu
    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        if [[ -z "$version_codename" ]]; then
            echo "${red}Error: Could not determine OS version codename${reset}"
            return 1
        fi

        # Create directory for keyrings if not exist
        if ! sudo install -m 0755 -d /etc/apt/keyrings; then
            echo "${red}Error: Failed to create /etc/apt/keyrings directory${reset}"
            return 1
        fi

        # Remove any existing Docker key
        sudo rm -f /etc/apt/keyrings/docker.gpg

        if ! curl -fsSL https://download.docker.com/linux/$os_id/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
            echo "${red}Error: Failed to download Docker GPG key${reset}"
            return 1
        fi
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$os_id \
            $version_codename stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

        if ! sudo apt update; then
            echo "${red}Error: Failed to update apt repositories${reset}"
            return 1
        fi

        if ! sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
            echo "${red}Error: Failed to install Docker packages${reset}"
            return 1
        fi
    elif [[ "$os_id" == "arch" ]]; then
        echo "Using ${yellow}paru${reset} to install Docker..."
        if ! paru -S --noconfirm --needed docker docker-compose docker-buildx; then
            echo "${red}Error: Failed to install Docker packages${reset}"
            return 1
        fi
    else
        echo "${red}Error: Unsupported OS: $os_id${reset}"
        return 1
    fi

    if ! sudo usermod -aG docker "$(whoami)"; then
        echo "${red}Error: Failed to add user to docker group${reset}"
        return 1
    fi

    if ! sudo systemctl enable docker; then
        echo "${red}Error: Failed to enable docker service${reset}"
        return 1
    fi

    if ! sudo systemctl restart docker; then
        echo "${red}Error: Failed to start docker service${reset}"
        return 1
    fi

    echo "${green}Docker installation complete.${reset}"
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_docker
fi
