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

# Agent theme palettes are pinned to odysseyalive/omarchy-seashells-theme@00dca31761374d5526790dd8a10271edbc6f9ec8.
# OMP owns its YAML layout and merges each managed setting into the current
# root config, leaving settings outside this contract untouched.
omp_agent_dir="$HOME/.omp/agent"
omp_config="$omp_agent_dir/config.yml"
mkdir -p "$omp_agent_dir/themes"
link_path "$dotfiles_dir/dot/.omp/agent/themes/seashells.json" \
    "$omp_agent_dir/themes/seashells.json"
link_path "$dotfiles_dir/dot/.omp/agent/themes/seashells-light.json" \
    "$omp_agent_dir/themes/seashells-light.json"

# Older revisions linked this path to the tracked template. Materialize its
# current contents before OMP's atomic partial-save so no write can reach Git.
omp_tracked_config="$dotfiles_dir/dot/.omp/agent/config.yml"
if [[ -L "$omp_config" ]] && [[ "$omp_config" -ef "$omp_tracked_config" ]]; then
    omp_config_tmp=$(mktemp "$omp_agent_dir/config.yml.XXXXXX")
    trap 'rm -f "$omp_config_tmp"' EXIT
    cp "$omp_config" "$omp_config_tmp"
    chmod 600 "$omp_config_tmp"
    mv "$omp_config_tmp" "$omp_config"
    trap - EXIT
fi

if command -v omp >/dev/null 2>&1; then
    omp config set theme.dark seashells </dev/null >/dev/null
    omp config set theme.light seashells-light </dev/null >/dev/null
    omp config set setupVersion 2 </dev/null >/dev/null
    omp_model_roles=$(
        omp config get modelRoles --json |
            jq -c '.value + {
                default: "openai-codex/gpt-5.6-sol:medium",
                smol: "openai-codex/gpt-5.6-luna:max",
                slow: "openai-codex/gpt-5.6-sol:xhigh"
            }'
    )
    omp config set modelRoles "$omp_model_roles" </dev/null >/dev/null
    omp config set tui.codexResetFireworks true </dev/null >/dev/null
    omp config set tui.tight false </dev/null >/dev/null
    omp config set statusLine.sessionAccent false </dev/null >/dev/null
    omp config set display.showTokenUsage true </dev/null >/dev/null
    omp config set symbolPreset nerd </dev/null >/dev/null
elif [[ ! -e "$omp_config" ]]; then
    cp "$dotfiles_dir/dot/.omp/agent/config.yml" "$omp_config"
    chmod 600 "$omp_config"
else
    printf 'OMP is not on PATH; preserving existing %s unchanged.\n' "$omp_config" >&2
fi

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
