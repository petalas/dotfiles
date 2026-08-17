#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/download.sh
source "$root_dir/lib/download.sh"

if command -v fc-list >/dev/null 2>&1 &&
    grep -Fiq 'Hack Nerd Font' <<<"$(fc-list)"; then
    echo "Hack Nerd Font is already installed."
    exit 0
fi

release=$(github_latest_tag ryanoasis/nerd-fonts)
font_dir="$HOME/.local/share/fonts/Hack"
[[ $(uname -s) != Darwin ]] || font_dir="$HOME/Library/Fonts/Hack"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fonts.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

archive=Hack.zip
download_file \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$release/$archive" \
    "$work_dir/$archive"
verify_sha256_manifest "$work_dir/$archive" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$release/SHA-256.txt" \
    "$archive"
mkdir -p "$font_dir"
unzip -qo "$work_dir/$archive" -d "$font_dir"
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null || echo "Warning: font cache rebuild failed." >&2
fi

echo "Installed Hack Nerd Font $release."
