#!/usr/bin/env bash

if [[ ! $OSTYPE == "darwin"* ]]; then
	echo "Not MacOS, exiting."
	exit 1
fi

red=$(tput setaf 1)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

# Check if Homebrew is installed
./setup-brew.sh

if ! command -v brew &>/dev/null; then
	echo "${red}Failed to install homebrew${reset}, check ${yellow}setup-brew.sh${reset}"
	exit 1
fi

## not managed by homebrew, have to create .nvm dir manually on first install
if [ ! -d "$HOME/.nvm" ]; then
	echo "Creating nvm dir: $HOME/.nvm"
	mkdir "$HOME/.nvm"
fi

printf "\nUpdating Homebrew...\n"
brew update && brew upgrade

# Translate user-facing SKIP_* env vars to HOMEBREW_SKIP_* so the Brewfile
# can see them. Homebrew strips non-HOMEBREW_ env vars before Brewfile eval.
for g in CAD GAMING MOBILE; do
	var="SKIP_$g"
	if [[ -n "${!var}" ]]; then
		export "HOMEBREW_SKIP_$g=1"
	fi
done

# Install everything declared in Brewfile.
# Per-machine subsetting: SKIP_CAD=1 SKIP_GAMING=1 SKIP_MOBILE=1 ./brew-deps.sh
# Drift check: brew bundle cleanup --file=Brewfile
brew bundle --file="$(dirname "$0")/Brewfile"

# source installers for non-brew deps (Node, Bun, Rust, SDKMAN)
source "$(dirname "$0")/installers/source_installers.sh"

install_node
install_bun
install_node_deps
install_sdkman
install_sdkman_deps
install_rust
install_rust_deps

# Informational drift check at the end of setup. Anything listed here is
# installed on this machine but not declared in Brewfile. Run with --force
# (manually, not here) to actually uninstall: brew bundle cleanup --file=Brewfile --force
printf "\n${yellow}Checking for drift (installed but not in Brewfile)...${reset}\n"
brew bundle cleanup --file="$(dirname "$0")/Brewfile" || true
