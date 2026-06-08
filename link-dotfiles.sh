#!/usr/bin/env bash

# shellcheck source=lib/git-sync.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/git-sync.sh"

# Link source to target, skipping if already correctly linked.
# Backs up existing files/dirs before replacing.
link_path() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        return 0
    fi

    [ -e "$target.old" ] && rm -rf "$target.old"
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "Creating backup: $target.old"
        cp -r "$target" "$target.old"
        rm -rf "$target"
    fi

    echo "Linking $source -> $target"
    ln -s "$source" "$target"
}

# ensure $HOME/.config exists
mkdir -p "$HOME/.config"

# activate repo's git hooks (.githooks/pre-commit runs shellcheck on *.sh)
git config core.hooksPath .githooks

# zshrc
link_path "$(pwd)/dot/zshrc" "$HOME/.zshrc"

# gitconfig
link_path "$(pwd)/dot/gitconfig" "$HOME/.gitconfig"

# work gitconfig
mkdir -p "$HOME/git/work"
link_path "$(pwd)/dot/work/gitconfig" "$HOME/git/work/.gitconfig"

# kitty
mkdir -p "$HOME/.config/kitty"
link_path "$(pwd)/dot/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# nvim — separate repo (petalas/nvim @ custom), cloned (NOT symlinked) into
# ~/.config/nvim, so it must be kept current explicitly or it silently drifts
# behind the plugins lazy.nvim keeps updating. See docs/LEARNINGS.md.
clone_or_ff https://github.com/petalas/nvim.git "$HOME/.config/nvim" custom

# yazi
link_path "$(pwd)/dot/.config/yazi" "$HOME/.config/yazi"
if command -v ya &>/dev/null; then
    ya pkg add boydaihungst/mediainfo
    ya pkg add kirasok/torrent-preview
fi

# bat
link_path "$(pwd)/dot/.config/bat" "$HOME/.config/bat"
if command -v bat &>/dev/null; then
    bat cache --build
fi

# ssh
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
link_path "$(pwd)/dot/.ssh/config.shared" "$HOME/.ssh/config.shared"

# ensure ~/.ssh/config includes the shared config
if [ ! -e "$HOME/.ssh/config" ]; then
    echo "Include ~/.ssh/config.shared" > "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    echo "Created $HOME/.ssh/config with Include directive"
elif ! grep -q "config.shared" "$HOME/.ssh/config"; then
    sed -i'' -e '1s/^/Include ~\/.ssh\/config.shared\n\n/' "$HOME/.ssh/config"
    echo "Added Include directive to $HOME/.ssh/config"
fi

# claude code
mkdir -p "$HOME/.claude/commands"

link_path "$(pwd)/dot/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link_path "$(pwd)/dot/claude/settings.json" "$HOME/.claude/settings.json"

# commands/ (symlink each .md file)
for cmd in $(pwd)/dot/claude/commands/*.md; do
    cmdname=$(basename "$cmd")
    link_path "$cmd" "$HOME/.claude/commands/$cmdname"
done
