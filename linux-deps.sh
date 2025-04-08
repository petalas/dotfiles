#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

os=""
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    os="${ID,,}"  # lowercase
else
    echo "Cannot determine OS."
    exit 1
fi

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
        "p7zip"
        "base-devel"            # includes gcc, g++, make, etc.
        "bind"                  # for dig, nslookup (dnsutils)
        "fd"
        "google-chrome"         # AUR: you'll need yay or paru
        "libnotify"
        "openssl"               # libssl-dev equivalent
        "perf"
        "pkgconf"
        "poppler"
        "python"
        "python-virtualenv"
        "openssh"
    )
else
    echo "Unsupported OS: $os"
    exit 1
fi

add_chrome_repo() {
    echo "Adding Google Chrome repo..."

    # Download the key and store it in a trusted keyring
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | \
        gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg >/dev/null

    # Create the source list
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" | \
        sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null

    # Update apt so it sees the new repo
    sudo apt update
}


# Update package list based on OS
if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    sudo apt update
    add_chrome_repo
elif [[ "$os" == "arch" ]]; then
    sudo pacman -Syu
    sudo pacman -S --noconfirm --needed reflector
    sudo reflector --threads 8 --latest 100 -n 10 --sort rate --save /etc/pacman.d/mirrorlist

    # Install paru (AUR helper)
    if ! command -v paru &>/dev/null; then
        echo "${yellow}paru${reset} not found. ${green}Installing...${reset}"
        sudo pacman -S --noconfirm --needed base-devel git

        tmp_dir="/tmp/paru-install"
        rm -rf "$tmp_dir"
        git clone https://aur.archlinux.org/paru.git "$tmp_dir"
        makepkg -si --noconfirm -C -p "$tmp_dir/PKGBUILD"
        rm -rf "$tmp_dir"
    fi
fi

# Function to check if a package is installed
is_installed() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0  # Package is installed
  else
    return 1  # Package is not installed
  fi
}

# Function to install packages using the appropriate package manager
install_package() {
  local package="$1"
  if command -v paru >/dev/null 2>&1; then
    # If using paru (pacman wrapper, AUR helper) (e.g., Arch Linux) - Non-interactive with --noconfirm
    paru -S --noconfirm --needed "$package" &>/dev/null || echo "Error installing ${yellow}$package${reset} with paru"
  elif command -v apt >/dev/null 2>&1; then
    # If using apt (e.g., Ubuntu, Debian) - Non-interactive with DEBIAN_FRONTEND=noninteractive
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get install -y "$package" &>/dev/null || echo "Error installing ${yellow}$package${reset} with apt"
  elif command -v dnf >/dev/null 2>&1; then
    # If using dnf (e.g., Fedora) - Non-interactive with -y
    sudo dnf install -y "$package" &>/dev/null || echo "Error installing ${yellow}$package${reset} with dnf"
  elif command -v yum >/dev/null 2>&1; then
    # If using yum (e.g., CentOS, RHEL) - Non-interactive with -y
    sudo yum install -y "$package" &>/dev/null || echo "Error installing ${yellow}$package${reset} with yum"
  else
    echo "No supported package manager found for ${yellow}$package${reset}."
  fi
}

# Iterate over dependencies and install missing ones
for dep in "${deps[@]}"; do
  if ! is_installed "$dep"; then
    echo "$dep is not installed. Attempting to install..."
    install_package "$dep"
  else
    echo "${yellow}$dep${reset} is ${green}already installed${reset}."
  fi
done

echo "${green}Installation complete.${reset}"

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