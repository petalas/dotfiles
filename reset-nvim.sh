#!/usr/bin/env bash
# Remove generated Neovim state without touching the separately managed config
# repository at ~/.config/nvim.
set -euo pipefail

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"

printf 'Removing generated Neovim state:\n  %s\n  %s\n  %s\n' \
    "$cache_dir" "$data_dir" "$state_dir"
rm -rf -- "$cache_dir" "$data_dir" "$state_dir"
