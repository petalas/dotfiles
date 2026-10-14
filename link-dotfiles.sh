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
mkdir -p "$HOME/.config/ghostty/themes"
link_path "$dotfiles_dir/dot/.config/ghostty/config.ghostty" \
    "$HOME/.config/ghostty/config.ghostty"
link_path "$dotfiles_dir/dot/.config/ghostty/themes/seashells" \
    "$HOME/.config/ghostty/themes/seashells"
link_path "$dotfiles_dir/dot/.config/ghostty/themes/seashells-light" \
    "$HOME/.config/ghostty/themes/seashells-light"
mkdir -p "$HOME/.config/kitty/themes"
link_path "$dotfiles_dir/dot/.config/kitty/kitty.conf" \
    "$HOME/.config/kitty/kitty.conf"
link_path "$dotfiles_dir/dot/.config/kitty/no-preference-theme.auto.conf" \
    "$HOME/.config/kitty/no-preference-theme.auto.conf"
link_path "$dotfiles_dir/dot/.config/kitty/light-theme.auto.conf" \
    "$HOME/.config/kitty/light-theme.auto.conf"
link_path "$dotfiles_dir/dot/.config/kitty/dark-theme.auto.conf" \
    "$HOME/.config/kitty/dark-theme.auto.conf"
link_path "$dotfiles_dir/dot/.config/kitty/themes/seashells.conf" \
    "$HOME/.config/kitty/themes/seashells.conf"
link_path "$dotfiles_dir/dot/.config/kitty/themes/seashells-light.conf" \
    "$HOME/.config/kitty/themes/seashells-light.conf"
link_path "$dotfiles_dir/dot/.config/yazi" "$HOME/.config/yazi"
link_path "$dotfiles_dir/dot/.config/bat" "$HOME/.config/bat"

# Zed preferences; editor state stays machine-local.
link_path "$dotfiles_dir/dot/.config/zed/settings.json" "$HOME/.config/zed/settings.json"

# Pi extensions/theme plus the one managed setting. Pi owns all other settings.
pi_agent_dir="$HOME/.pi/agent"
pi_settings="$pi_agent_dir/settings.json"
mkdir -p "$pi_agent_dir/extensions" "$pi_agent_dir/themes"
link_path "$dotfiles_dir/dot/.pi/agent/extensions/openai-fast-mode.ts" \
    "$pi_agent_dir/extensions/openai-fast-mode.ts"
link_path "$dotfiles_dir/dot/.pi/agent/themes/seashells.json" \
    "$pi_agent_dir/themes/seashells.json"
link_path "$dotfiles_dir/dot/.pi/agent/themes/seashells-light.json" \
    "$pi_agent_dir/themes/seashells-light.json"
merge_json_setting "$pi_settings" '.theme = "seashells"'

# Retire only this checkout's former OMP links, including dangling config/theme
# links. Machine-owned files, backups, credentials, and session history stay put.
for omp_agent_dir in "$HOME/.omp/agent" "$HOME/.omp/profiles/work/agent" \
    "$HOME/.omp/profiles/deepseek/agent" "$HOME/.omp/profiles/free/agent"; do
    for omp_link in "$omp_agent_dir/config.yml" "$omp_agent_dir/AGENTS.md" \
        "$omp_agent_dir/themes/seashells.json" "$omp_agent_dir/themes/seashells-light.json"; do
        if [[ ! -L "$omp_link" ]]; then
            continue
        fi
        omp_source=$(readlink "$omp_link")
        case "$omp_source" in
            "$dotfiles_dir/dot/.omp/agent/config.yml"|\
            "$dotfiles_dir/dot/.omp/agent/config-work.yml"|\
            "$dotfiles_dir/dot/.omp/agent/config-deepseek.yml"|\
            "$dotfiles_dir/dot/.omp/agent/config-free.yml"|\
            "$dotfiles_dir/dot/.omp/agent/themes/seashells.json"|\
            "$dotfiles_dir/dot/.omp/agent/themes/seashells-light.json"|\
            "$dotfiles_dir/dot/AGENTS.md")
                rm -f -- "$omp_link"
                echo "Removed retired OMP link: $omp_link"
                ;;
        esac
    done
done
unset omp_agent_dir omp_link omp_source

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

# Claude Code global instructions.
link_path "$dotfiles_dir/dot/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Harness-neutral global agent instructions. CLAUDE.md imports the Claude copy; the
# other harnesses read their own global AGENTS.md path directly.
for agents_target in "$HOME/.claude/AGENTS.md" "$HOME/.codex/AGENTS.md" \
    "$HOME/.pi/agent/AGENTS.md"; do
    link_path "$dotfiles_dir/dot/AGENTS.md" "$agents_target"
done
# Claude Code owns ~/.claude/settings.json (it writes theme and prompt state into
# it), so the file stays machine-local and only the managed keys are merged in.
merge_json_setting "$HOME/.claude/settings.json" '.autoMemoryEnabled = false'
