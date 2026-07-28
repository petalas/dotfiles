#!/usr/bin/env bash
set -euo pipefail

if [[ "${DOTFILES_INTEGRATION_TEST:-0}" == 1 ]]; then
    echo "Skipping fonts in the container."
    exit 0
fi

if command -v fc-list >/dev/null 2>&1 &&
    grep -Fiq 'Hack Nerd Font' <<<"$(fc-list)"; then
    echo "Hack Nerd Font is already installed."
    exit 0
fi

release=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest |
    jq -r .tag_name)
font_dir="$HOME/.local/share/fonts/Hack"
[[ $OSTYPE != darwin* ]] || font_dir="$HOME/Library/Fonts/Hack"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fonts.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

curl -fL --retry 3 \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$release/Hack.zip" \
    -o "$work_dir/Hack.zip"
mkdir -p "$font_dir"
unzip -qo "$work_dir/Hack.zip" -d "$font_dir"
command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null || true

echo "Installed Hack Nerd Font $release."
