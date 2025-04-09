#!/usr/bin/env bash

set -e # exit on error

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

os=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

declare -a deps=(
    "bat"
    "bc"
    "btop"
    "ca-certificates"
    "clang"
    "cmake"
    "curl"
    "ffmpeg"
    "fzf"
    "git"
    "gnupg"
    "grep"
    "htop"
    "imagemagick"
    "iperf3"
    "iptables"
    "jq"
    "mediainfo"
    "nmap"
    "pass"
    "shellcheck"
    "sshpass"
    "tar"
    "tldr"
    "tmux"
    "unzip"
    "wget"
    "xclip"
    "xdg-utils"
    "zip"
    "zsh"
)

# Add OS-specific packages
if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    deps+=(
        "7zip"
        "apt-transport-https"
        "build-essential"
        "dnsutils"
        "fd-find"
        "g++"
        "gcc"
        "google-chrome-stable"
        "gpg"
        "libnotify4"
        "libssl-dev"
        "linux-perf"
        "make"
        "pkg-config"
        "poppler-utils"
        "python3"
        "python3-venv"
        "ssh"
    )
elif [[ "$os" == "arch" ]]; then
    deps+=(
        "base-devel" # includes gcc, g++, make, etc.
        "bind"       # for dig, nslookup (dnsutils)
        "fd"
        "google-chrome" # AUR: you'll need yay or paru
        "libnotify"
        "openssh"
        "openssl" # libssl-dev equivalent
        "p7zip"
        "perf"
        "pkgconf"
        "poppler"
        "python"
        "python-virtualenv"
        "spotify"
    )
else
    echo "Unsupported OS: $os"
    exit 1
fi

add_chrome_repo() {
    echo "Adding Google Chrome repo..."

    # Download the key and store it in a trusted keyring
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub |
        gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg >/dev/null

    # Create the source list
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" |
        sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null

    # Update apt so it sees the new repo
    sudo apt update
}

install_paru() {
    echo
    echo ":: Installing ${yellow}paru${reset}..."
    sudo pacman -S --noconfirm --needed base-devel git bat
    SCRIPT=$(realpath "$0")
    original_dir=$(dirname "$SCRIPT")
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru
    makepkg -si --noconfirm
    cd "$original_dir"
    echo ":: ${yellow}paru${reset} has been ${green}installed successfully${reset}."
    echo
}

set_parallel_downloads() {
    local value="$1"
    local conf="/etc/pacman.conf"

    # Check if the line already exists (commented or uncommented)
    if grep -qE "^\s*#?\s*ParallelDownloads\s*=" "$conf"; then
        # Replace existing line
        sudo sed -i "s|^\s*#\?\s*ParallelDownloads\s*=.*|ParallelDownloads = $value|" "$conf"
    else
        # Add under the [options] section
        sudo sed -i "/^\[options\]/a ParallelDownloads = $value" "$conf"
    fi
}

# Update package list based on OS
if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    sudo apt update
    add_chrome_repo
elif [[ "$os" == "arch" ]]; then
    set_parallel_downloads 8 # default is 5, probably won't make much of a difference
    sudo pacman -Syu
    sudo pacman -S --noconfirm --needed reflector
    echo ":: Finding the ${green}fastest mirrors${reset}, this might take a while..."
    sudo reflector --threads 8 --latest 100 -n 10 --connection-timeout 1 --download-timeout 1 --sort rate --save /etc/pacman.d/mirrorlist >/dev/null 2>&1
    echo "$(cat /etc/pacman.d/mirrorlist)"
    echo ":: ${green}Fastest mirrors found!${reset}"

    if ! command -v paru &>/dev/null; then
        install_paru
    fi
fi

# Function to check if a package is installed
is_installed() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0 # Package is installed
    else
        return 1 # Package is not installed
    fi
}

# Function to install packages using the appropriate package manager
install_deps() {
    local packages=("$@")
    echo
    echo ":: ${yellow}Installing ${green}${packages[*]}${reset}..."
    echo
    if command -v paru >/dev/null 2>&1; then
        # If using paru (pacman wrapper, AUR helper) (e.g., Arch Linux) - Non-interactive with --noconfirm
        paru -S --noconfirm --needed "${packages[@]}" || echo "Error installing ${yellow}${packages[*]}${reset} with paru"
    elif command -v apt >/dev/null 2>&1; then
        # If using apt (e.g., Ubuntu, Debian) - Non-interactive with DEBIAN_FRONTEND=noninteractive
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get install -y "${packages[@]}" || echo "Error installing ${yellow}${packages[*]}${reset} with apt"
    elif command -v dnf >/dev/null 2>&1; then
        # If using dnf (e.g., Fedora) - Non-interactive with -y
        sudo dnf install -y "${packages[@]}" || echo "Error installing ${yellow}${packages[*]}${reset} with dnf"
    elif command -v yum >/dev/null 2>&1; then
        # If using yum (e.g., CentOS, RHEL) - Non-interactive with -y
        sudo yum install -y "${packages[@]}" || echo "Error installing ${yellow}${packages[*]}${reset} with yum"
    else
        echo "${red}No supported package manager found.${reset}"
    fi
}

# Iterate over dependencies and install missing ones
install_missing_deps() {
    pending=()
    for dep in "${deps[@]}"; do
        if is_installed "$dep"; then
            echo "${yellow}$dep${reset} is ${green}already installed${reset}."
        else
            pending+=("$dep")
        fi
    done
    if [[ "${pending[@]}" == "" ]]; then
        echo ":: ${green}All base dependencies are already installed.${reset}"
        return
    fi
    install_deps "${pending[@]}"
}

install_missing_deps
echo
echo "${green}Base dependencies => Installation complete.${reset}"
echo

# Source all installer scripts
source "$(dirname "$0")/installers/source_installers.sh"

# Run all installers
echo "${yellow}Running installers...${reset}"
install_bitwarden || echo "${red}Failed to install bitwarden${reset}"
install_bun || echo "${red}Failed to install bun${reset}"
install_code || echo "${red}Failed to install code${reset}"
install_discord || echo "${red}Failed to install discord${reset}"
install_docker || echo "${red}Failed to install docker${reset}"
install_kitty || echo "${red}Failed to install kitty${reset}"
install_lazydocker || echo "${red}Failed to install lazydocker${reset}"
install_lazygit || echo "${red}Failed to install lazygit${reset}"
install_neovim || echo "${red}Failed to install neovim${reset}"
install_node || echo "${red}Failed to install node${reset}"
install_node_deps || echo "${red}Failed to install node_deps${reset}"
install_sdkman || echo "${red}Failed to install sdkman${reset}"
install_sdkman_deps || echo "${red}Failed to install sdkman_deps${reset}"
install_rust || echo "${red}Failed to install rust${reset}"
install_rust_deps || echo "${red}Failed to install rust_deps${reset}"
install_zerotier || echo "${red}Failed to install zerotier${reset}"
