#!/bin/bash

echo 'Checking rosetta installation...'
if [[ "`pkgutil --files com.apple.pkg.RosettaUpdateAuto`" == "" ]]
then 
	echo 'Not detected, installing rosetta...'
	sudo softwareupdate --install-rosetta
else
	echo 'rosetta is already installed.'
fi

echo "Checking Hombrew installation..."
if [[ $(command -v brew) == "" ]]; then
    echo "Not detected, installing Hombrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "Updating Homebrew..."
brew update && brew upgrade