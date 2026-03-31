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

if ! brew tap | grep -qx "mobile-dev-inc/tap"; then
	echo "Tapping ${yellow}mobile-dev-inc/tap${reset}"
	brew tap mobile-dev-inc/tap
fi

## Fetch installed lists once (avoids ~55 individual brew calls)
installed_formulae=$(brew list --formula -1)
installed_casks=$(brew list --cask -1)

## Install dependencies
echo "Checking dependencies..."
declare -a deps=(
	"aria2"
	"bash"
	"bc"
	"bind"
	"btop"
	"cmake"
	"elixir"
	"eza"
	"fd"
	"ffmpeg"
	"fastlane"
	"fzf"
	"gcc"
	"gh"
	"gnupg"
	"htop"
	"imagemagick"
	"iperf3"
	"jq"
	"lazydocker"
	"lazygit"
	"media-info"
	"mtr"
	"neovim"
	"nmap"
	"nvm"
	"poppler"
	"python@3.14"
	"python-setuptools"
	"rsync"
	"sevenzip"
	"tldr"
	"watch"
	"wget"
	"yt-dlp"
)
for i in "${deps[@]}"; do
	if echo "$installed_formulae" | grep -qx "$i"; then
		echo "${yellow}$i${reset} is ${green}already installed${reset}."
	else
		echo "Installing ${yellow}$i${reset}"
		brew install "$i"
	fi
done

if echo "$installed_formulae" | grep -qx "maestro"; then
	echo "${yellow}maestro${reset} is ${green}already installed${reset}."
else
	echo "Installing ${yellow}mobile-dev-inc/tap/maestro${reset}"
	brew install mobile-dev-inc/tap/maestro
fi

printf "\n\nChecking cask dependencies...\n"
declare -a caskdeps=(
	"bambu-studio"
	"bitwarden"
	"capcut"
	"codex-app"
	"dbeaver-community"
	"discord"
	"docker"
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
	"syncthing-app"
	"tailscale-app"
	"temurin@17"
	"visual-studio-code"
	"vlc"
	"whatsapp"
	"zed@preview"
)
for i in "${caskdeps[@]}"; do
	if echo "$installed_casks" | grep -qx "$i"; then
		echo "${yellow}$i${reset} is ${green}already installed${reset}."
	else
		echo "Installing ${yellow}$i${reset}"
		brew install --cask "$i"
	fi
done

# source installers
source "$(dirname "$0")/installers/source_installers.sh"

install_node
install_bun
install_node_deps
install_sdkman
install_sdkman_deps
install_rust
install_rust_deps
