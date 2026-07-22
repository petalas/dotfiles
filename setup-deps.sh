#!/usr/bin/env bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

# Establish a valid locale before package managers and downstream installers
# run. setup_locale bootstraps its own OS package when necessary.
./install locale

# MacOS dependencies managed by homebrew
if [[ $OSTYPE == "darwin"* ]]; then
	./brew-deps.sh
elif [[ $OSTYPE == "linux"* ]]; then
	./linux-deps.sh
else
	echo "Unsupported OS: $OSTYPE" >&2
	exit 1
fi
