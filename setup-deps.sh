#!/usr/bin/env bash

# MacOS dependencies managed by homebrew
if [[ $OSTYPE == "darwin"* ]]; then
    ./brew-deps.sh
elif [[ $OSTYPE == "linux"* ]]; then
    ./linux-deps.sh
fi