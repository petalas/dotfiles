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
    "fd"
    "ffmpeg"
    "gcc"
    "htop"
    "iperf3"
    "jq"
    "lazydocker"
    "lazygit"
    "mediainfo"
    "neovim"
    "nvm"
    "python"
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
    "alacritty"
    "alfred"
    "background-music"
    "discord"
    "docker"
    "dropbox"
    "google-chrome"
    "iterm2"
    "keepassxc"
    "microsoft-teams"
    "openvpn-connect"
    "qbittorrent"
    "skype"
    "steam"
    "sublime-text"
    "teamviewer"
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
