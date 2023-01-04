#!/bin/bash

if [[ ! $OSTYPE == "darwin"* ]]; then
    echo "Not MacOS, exiting."
    exit 1
fi

if [[ $(uname -p) == 'arm' ]]; then # detect Apple Silicon
    echo "Checking rosetta installation..."
    if [[ "`pkgutil --files com.apple.pkg.RosettaUpdateAuto`" == "" ]]
    then
        echo "Not detected, installing rosetta..."
        sudo softwareupdate --install-rosetta
    else
        echo "rosetta is already installed."
    fi
fi

printf "\n\nChecking Hombrew installation...\n"
if [[ $(command -v brew) == "" ]]; then
    echo "Not detected, installing Hombrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

./brew-deps.sh