#!/bin/bash

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

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
	"ffmpeg"
	"htop"
	"mediainfo"
	"java"
	"jq"
	"nvm"
	"python"
	"watch"
	"youtube-dl"
	)
for i in "${deps[@]}"
do
	if [[ $(brew ls --versions $i) == "" ]]; then
		echo "Installing ${yellow}$i${reset}"
		brew install $i
	else
		echo "${yellow}$i${reset} is ${green}already installed${reset}."
	fi
done

printf "\n\nChecking cask dependencies...\n"
declare -a caskdeps=(
	"alfred"
	"docker"
	"dropbox"
	"discord"
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
for i in "${caskdeps[@]}"
do
	if [[ $(brew ls --cask --versions $i) == "" ]]; then
		echo "Installing ${yellow}$i${reset}"
		brew install --cask $i
	else
		echo "${yellow}$i${reset} is ${green}already installed${reset}."
	fi
done



