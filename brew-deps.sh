#!/bin/bash

if [[ ! $OSTYPE == "darwin"* ]]; then
    echo "Not MacOS, exiting."
    exit 1
fi

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

# Check if Homebrew is installed
./setup-brew.sh

if ! which brew &> /dev/null; then
    echo "${red}Failed to install homebrew${reset}, check ${yellow}setup-brew.sh${reset}"
    exit 1
fi

## not managed by homebrew, have to create .nvm dir manually on first install
if [ ! -d "$HOME/.nvm" ]; then
    echo "Creating nvm dir: $HOME/.nvm"
    mkdir $HOME/.nvm
fi

printf "\nUpdating Homebrew...\n"
brew update && brew upgrade

## Install dependencies
echo "Checking dependencies..."
declare -a deps=(
    "aria2"
    "bc"
    "bind"
    "btop"
    "cmake"
    "elixir"
    "fd"
    "ffmpeg"
    "gcc"
    "gnupg"
    "htop"
    "imagemagick"
    "iperf3"
    "jq"
    "lazydocker"
    "lazygit"
    "mediainfo"
    "neovim"
    "nmap"
    "nvm"
    "python"
    "python3-setuptools"
    "watch"
    "yt-dlp"
)
for i in "${deps[@]}"; do
    if [[ $(brew ls --versions $i) == "" ]]; then
        echo "Installing ${yellow}$i${reset}"
        brew install --no-quarantine $i
    else
        echo "${yellow}$i${reset} is ${green}already installed${reset}."
    fi
done

printf "\n\nChecking cask dependencies...\n"
declare -a caskdeps=(
    "bambu-studio"
    "bitwarden"
    "dbeaver-community"
    "discord"
    "docker"
    "dropbox"
    "firefox@developer-edition"
    "jordanbaird-ice"
    "keka"
    "kitty"
    "openscad"
    "parsec"
    "private-internet-access"
    "qbittorrent"
    "raycast"
    "rectangle"
    "skype"
    "spotify"
    "stats"
    "steam"
    "sublime-text"
    "visual-studio-code"
    "vlc"
    "whatsapp"
)
for i in "${caskdeps[@]}"; do
    if [[ $(brew ls --cask --versions $i) == "" ]]; then
        echo "Installing ${yellow}$i${reset}"
        brew install --no-quarantine --cask $i
    else
        echo "${yellow}$i${reset} is ${green}already installed${reset}."
    fi
done
