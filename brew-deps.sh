#!/usr/bin/env bash

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

if ! which brew &>/dev/null; then
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
	"eza"
	"fd"
	"ffmpeg"
	"fzf"
	"gcc"
	"gnupg"
	"htop"
	"imagemagick"
	"iperf3"
	"jq"
	"lazydocker"
	"lazygit"
	"mediainfo"
	"mtr"
	"neovim"
	"nmap"
	"nvm"
	"poppler"
	"python"
	"python-setuptools"
	"sevenzip"
	"tldr"
	"watch"
	"wget"
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
	"gimp"
	"google-chrome"
	"grandperspective"
	"jordanbaird-ice"
	"keka"
	"kitty"
	"openscad@snapshot"
	"parsec"
	"private-internet-access"
	"qbittorrent"
	"raycast"
	"rectangle"
	"slack"
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

# source installers
source "$(dirname "$0")/installers/source_installers.sh"

install_node
install_node_deps
install_sdkman
install_sdkman_deps
install_rust
install_rust_deps
