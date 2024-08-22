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
    "cmake"
    "fd"
    "ffmpeg"
    "gcc"
    "gnupg"
    "htop"
    "hudochenkov/sshpass/sshpass"
    "iperf3"
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
    "alacritty"
    "alfred"
    "background-music"
    "bitwarden"
    "discord"
    "docker"
    "dropbox"
    "google-chrome"
    "iterm2"
    "keepassxc"
    "kitty"
    "microsoft-teams"
    "openvpn-connect"
    "parsec"
    "private-internet-access"
    "qbittorrent"
    "skype"
    "steam"
    "sublime-text"
    "teamviewer"
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
