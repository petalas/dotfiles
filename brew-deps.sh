#!/bin/bash

## not managed by homebrew, have to create .nvm dir manually on first install
if [ ! -d "$HOME/.nvm" ]; then
	echo "Creating nvm dir: $HOME/.nvm"
	mkdir $HOME/.nvm
fi

## Install dependencies
echo "Checking dependencies..."
declare -a deps=("java" "htop" "nvm" "jq" "ffmpeg" "youtube-dl" "watch" "python")
for i in "${deps[@]}"
do
	if [[ $(brew ls --versions $i) == "" ]]; then
		echo "Installing $i"
		brew install $i
	else
		echo "$i is already installed."
	fi
done

printf "\n\nChecking cask dependencies...\n"
declare -a caskdeps=("iterm2" "visual-studio-code" "google-chrome" "keepassxc" "dropbox" "microsoft-teams" "openvpn-connect" "docker" "vlc" "steam" "skype")
for i in "${caskdeps[@]}"
do
	if [[ $(brew ls --cask --versions $i) == "" ]]; then
		echo "Installing $i"
		brew install --cask $i
	else
		echo "$i is already installed."
	fi
done

