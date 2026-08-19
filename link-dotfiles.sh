#!/usr/bin/env bash
# Link tracked configuration into $HOME. This script performs no downloads or
# package/plugin installation; it is safe to use after an ordinary git pull.
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/link.sh disable=SC1091
source "$dotfiles_dir/lib/link.sh"
# shellcheck source=lib/obsidian.sh disable=SC1091
source "$dotfiles_dir/lib/obsidian.sh"

mkdir -p "$HOME/.config"
git -C "$dotfiles_dir" config core.hooksPath .githooks

# Shell and prompt.
link_path "$dotfiles_dir/dot/zshrc" "$HOME/.zshrc"
link_path "$dotfiles_dir/dot/seashells.zsh" "$HOME/.seashells.zsh"
link_path "$dotfiles_dir/dot/p10k-seashells.zsh" "$HOME/.p10k-seashells.zsh"
link_path "$dotfiles_dir/dot/hushlogin" "$HOME/.hushlogin"

# Git.
link_path "$dotfiles_dir/dot/gitconfig" "$HOME/.gitconfig"
mkdir -p "$HOME/git/work"
link_path "$dotfiles_dir/dot/work/gitconfig" "$HOME/git/work/.gitconfig"

# Terminal tools.
link_path "$dotfiles_dir/dot/tmux.conf" "$HOME/.tmux.conf"
mkdir -p "$HOME/.config/ghostty"
link_path "$dotfiles_dir/dot/.config/ghostty/config.ghostty" \
    "$HOME/.config/ghostty/config.ghostty"
link_path "$dotfiles_dir/dot/.config/yazi" "$HOME/.config/yazi"
link_path "$dotfiles_dir/dot/.config/bat" "$HOME/.config/bat"

# Pi extensions/theme plus the one managed setting. Pi owns all other settings.
pi_agent_dir="$HOME/.pi/agent"
pi_settings="$pi_agent_dir/settings.json"
mkdir -p "$pi_agent_dir/extensions" "$pi_agent_dir/themes"
link_path "$dotfiles_dir/dot/.pi/agent/extensions/openai-fast-mode.ts" \
    "$pi_agent_dir/extensions/openai-fast-mode.ts"
link_path "$dotfiles_dir/dot/.pi/agent/themes/seashells.json" \
    "$pi_agent_dir/themes/seashells.json"
pi_settings_tmp=$(mktemp "$pi_agent_dir/settings.json.XXXXXX")
trap 'rm -f "$pi_settings_tmp"' EXIT
if [[ -f "$pi_settings" ]]; then
    jq '.theme = "seashells"' "$pi_settings" >"$pi_settings_tmp"
else
    jq -n '{theme: "seashells"}' >"$pi_settings_tmp"
fi
chmod 600 "$pi_settings_tmp"
mv "$pi_settings_tmp" "$pi_settings"
trap - EXIT

link_obsidian_vault_settings "$dotfiles_dir"

# SSH. Keep the machine-owned config and add one exact active Include line.
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
link_path "$dotfiles_dir/dot/.ssh/config.shared" "$HOME/.ssh/config.shared"
ssh_config="$HOME/.ssh/config"
if [[ ! -e "$ssh_config" ]]; then
    printf 'Include ~/.ssh/config.shared\n' >"$ssh_config"
    echo "Created $ssh_config with Include directive"
elif ! awk '
    /^[[:space:]]*#/ { next }
    tolower($1) == "include" {
        for (i = 2; i <= NF; i++) {
            if ($i == "~/.ssh/config.shared") found = 1
        }
    }
    END { exit !found }
' "$ssh_config"; then
    ssh_config_tmp=$(mktemp "$HOME/.ssh/config.XXXXXX")
    trap 'rm -f "$ssh_config_tmp"' EXIT
    {
        printf 'Include ~/.ssh/config.shared\n\n'
        cat "$ssh_config"
    } >"$ssh_config_tmp"
    chmod 600 "$ssh_config_tmp"
    mv "$ssh_config_tmp" "$ssh_config"
    trap - EXIT
    echo "Added Include directive to $ssh_config"
fi
chmod 600 "$ssh_config"

# Claude Code global instructions and commands.
mkdir -p "$HOME/.claude/commands"
link_path "$dotfiles_dir/dot/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
if [[ -e "$dotfiles_dir/dot/claude/settings.json" ]]; then
    link_path "$dotfiles_dir/dot/claude/settings.json" "$HOME/.claude/settings.json"
fi
while IFS= read -r -d '' command_file; do
    command_name=$(basename "$command_file")
    link_path "$command_file" "$HOME/.claude/commands/$command_name"
done < <(find "$dotfiles_dir/dot/claude/commands" -maxdepth 1 -type f -name '*.md' -print0)
