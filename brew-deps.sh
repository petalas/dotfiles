#!/bin/bash

if [[ ! $OSTYPE == "darwin"* ]]; then
    echo "Not MacOS, exiting."
    exit 1
fi

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

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
    "fd"
    "ffmpeg"
    "gcc"
    "gnupg"
    "htop"
    "hudochenkov/sshpass/sshpass"
    "iperf3"
    "jordanbaird-ice"
    "jq"
    "lazydocker"
    "lazygit"
    "mediainfo"
    "neovim"
    "nmap"
    "nvm"
    "pass"
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
    "bitwarden"
    "discord"
    "docker"
    "dropbox"
    "kitty"
    "microsoft-teams"
    "openvpn-connect"
    "parsec"
    "private-internet-access"
    "qbittorrent"
    "raycast"
    "rectangle"
    "skype"
    "stats"
    "steam"
    "sublime-text"
    "the-unarchiver"
    "visual-studio-code"
    "vlc"
    "whatsapp"
    "zerotier-one"
)
for i in "${caskdeps[@]}"; do
    if [[ $(brew ls --cask --versions $i) == "" ]]; then
        echo "Installing ${yellow}$i${reset}"
        brew install --no-quarantine --cask $i
    else
        echo "${yellow}$i${reset} is ${green}already installed${reset}."
    fi
done
