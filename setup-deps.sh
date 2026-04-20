#!/usr/bin/env bash
set -e

# MacOS dependencies managed by homebrew
if [[ $OSTYPE == "darwin"* ]]; then
	./brew-deps.sh
elif [[ $OSTYPE == "linux"* ]]; then
	./linux-deps.sh
else
	echo "Unsupported OS: $OSTYPE" >&2
	exit 1
fi
