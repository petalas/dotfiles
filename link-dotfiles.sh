#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/git-sync.sh disable=SC1091
source "$dotfiles_dir/lib/git-sync.sh"

# Link source to target, skipping if already correctly linked.
# Backs up existing files/dirs before replacing.
link_path() {
    local source="$1"
    local target="$2"

    if [ ! -e "$source" ]; then
        echo "Cannot link missing source: $source" >&2
        return 1
    fi

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        return 0
    fi

    if [ -e "$target.old" ] || [ -L "$target.old" ]; then
        rm -rf "$target.old"
    fi
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
git -C "$dotfiles_dir" config core.hooksPath .githooks

# zshrc
link_path "$dotfiles_dir/dot/zshrc" "$HOME/.zshrc"

# gitconfig
link_path "$dotfiles_dir/dot/gitconfig" "$HOME/.gitconfig"

# work gitconfig
mkdir -p "$HOME/git/work"
link_path "$dotfiles_dir/dot/work/gitconfig" "$HOME/git/work/.gitconfig"

# tmux + plugins
link_path "$dotfiles_dir/dot/tmux.conf" "$HOME/.tmux.conf"
clone_or_ff https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm"
if command -v tmux &>/dev/null; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
fi

# kitty
mkdir -p "$HOME/.config/kitty"
link_path "$dotfiles_dir/dot/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# nvim — separate repo (petalas/nvim @ custom), cloned (NOT symlinked) into
# ~/.config/nvim, so it must be kept current explicitly or it silently drifts
# behind the plugins lazy.nvim keeps updating. See docs/LEARNINGS.md.
clone_or_ff https://github.com/petalas/nvim.git "$HOME/.config/nvim" custom

# yazi
link_path "$dotfiles_dir/dot/.config/yazi" "$HOME/.config/yazi"
if command -v ya &>/dev/null; then
    ya pkg add boydaihungst/mediainfo
    ya pkg add kirasok/torrent-preview
fi

# bat
link_path "$dotfiles_dir/dot/.config/bat" "$HOME/.config/bat"
if command -v bat &>/dev/null; then
    bat cache --build
fi

# ssh
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
link_path "$dotfiles_dir/dot/.ssh/config.shared" "$HOME/.ssh/config.shared"

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

link_path "$dotfiles_dir/dot/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link_path "$dotfiles_dir/dot/claude/settings.json" "$HOME/.claude/settings.json"

# commands/ (symlink each .md file)
for cmd in "$dotfiles_dir"/dot/claude/commands/*.md; do
    cmdname=$(basename "$cmd")
    link_path "$cmd" "$HOME/.claude/commands/$cmdname"
done
