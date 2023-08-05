#!/bin/bash

if [[ $OSTYPE == "linux"* || $OSTYPE == "darwin"* ]]; then
    echo "resetting neovim cache, plugins, data"
    rm -rf ~/.cache/nvim ~/.config/nvim/plugin ~/.local/share/nvim ~/.config/nvim/plugin
fi
