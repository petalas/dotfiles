#!/usr/bin/env bash

if [[ ! $OSTYPE == "darwin"* ]]; then
    echo "Not MacOS, exiting."
    exit 1
fi

if [[ $(uname -p) == 'arm' ]]; then # detect Apple Silicon
    echo "Checking rosetta installation..."
    if [[ "$(pkgutil --files com.apple.pkg.RosettaUpdateAuto)" == "" ]]; then
        echo "Not detected, installing rosetta..."
        sudo softwareupdate --install-rosetta
    else
        echo "rosetta is already installed."
    fi
fi

printf "\n\nChecking Hombrew installation...\n"
if ! which brew &>/dev/null; then
    echo "Homebrew not found, installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Determine correct profile file based on shell
    if [[ "$SHELL" == */zsh ]]; then
        profile_file="$HOME/.zprofile"
    else
        profile_file="$HOME/.bash_profile"
    fi

    # Add Homebrew to PATH
    echo 'export PATH="/opt/homebrew/bin:$PATH"' >> "$profile_file"

    # Source the profile file
    source "$profile_file"

    # reload zsh
    exec zsh
fi
