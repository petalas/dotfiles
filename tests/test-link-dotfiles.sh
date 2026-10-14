#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-link-all.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
# Writes through linked preferences must never touch the real checkout.
git init -q "$fixture/repo"
cp -R "$repo_dir/dot" "$repo_dir/lib" "$repo_dir/link-dotfiles.sh" "$fixture/repo/"
repo_dir="$fixture/repo"
mkdir -p "$fixture/home/.ssh" "$fixture/home/.pi/agent" \
    "$fixture/home/git/notes" "$fixture/home/.claude"
printf '# Include ~/.ssh/config.shared\nHost example\n' >"$fixture/home/.ssh/config"
printf '{"defaultModel":"test"}\n' >"$fixture/home/.pi/agent/settings.json"
printf '{"theme":"dark"}\n' >"$fixture/home/.claude/settings.json"

# Simulate a previously linked machine after the tracked OMP sources are deleted.
# Runtime sentinels and backups must survive cleanup and repeated relinking.
omp_agents=(.omp/agent .omp/profiles/work/agent .omp/profiles/deepseek/agent .omp/profiles/free/agent)
omp_configs=(config.yml config-work.yml config-deepseek.yml config-free.yml)
for index in 0 1 2 3; do
    agent_dir="$fixture/home/${omp_agents[index]}"
    mkdir -p "$agent_dir/themes" "$agent_dir/sessions"
    ln -s "$repo_dir/dot/.omp/agent/${omp_configs[index]}" "$agent_dir/config.yml"
    ln -s "$repo_dir/dot/.omp/agent/themes/seashells.json" "$agent_dir/themes/seashells.json"
    ln -s "$repo_dir/dot/.omp/agent/themes/seashells-light.json" "$agent_dir/themes/seashells-light.json"
    ln -s "$repo_dir/dot/AGENTS.md" "$agent_dir/AGENTS.md"
    printf 'machine-runtime\n' >"$agent_dir/agent.db"
    printf 'machine-session\n' >"$agent_dir/sessions/session.json"
    printf 'old: machine settings\n' >"$agent_dir/config.yml.old"
done
# Profiles that were never managed remain untouched.
mkdir -p "$fixture/home/.omp/profiles/personal/agent"
printf 'personal: settings\n' >"$fixture/home/.omp/profiles/personal/agent/config.yml"
for _ in 1 2; do
    HOME="$fixture/home" PATH="/usr/bin:/bin" "$repo_dir/link-dotfiles.sh"
done

[[ -L "$fixture/home/.zshrc" ]]
[[ -L "$fixture/home/.config/yazi" ]]
[[ -L "$fixture/home/git/notes/.obsidian/app.json" ]]
jq -e '.alwaysUpdateLinks == true' \
    "$fixture/home/git/notes/.obsidian/app.json" >/dev/null
[[ "$(grep -Ec '^[[:space:]]*Include ~/.ssh/config.shared' "$fixture/home/.ssh/config")" == 1 ]]
[[ "$(stat -c '%a' "$fixture/home/.ssh/config" 2>/dev/null || stat -f '%Lp' "$fixture/home/.ssh/config")" == 600 ]]
jq -e '.theme == "seashells" and .defaultModel == "test"' \
    "$fixture/home/.pi/agent/settings.json" >/dev/null
[[ "$(stat -c '%a' "$fixture/home/.pi/agent/settings.json" 2>/dev/null || stat -f '%Lp' "$fixture/home/.pi/agent/settings.json")" == 600 ]]
[[ ! -L "$fixture/home/.pi/agent/settings.json" ]]
jq -e '.autoMemoryEnabled == false and .theme == "dark"' \
    "$fixture/home/.claude/settings.json" >/dev/null
[[ ! -L "$fixture/home/.claude/settings.json" ]]

for variant in seashells seashells-light; do
    theme="$fixture/home/.pi/agent/themes/$variant.json"
    [[ -L "$theme" ]]
    [[ "$(readlink "$theme")" == "$repo_dir/dot/.pi/agent/themes/$variant.json" ]]
    jq -e --arg name "$variant" '.name == $name' "$theme" >/dev/null
done
[[ -L "$fixture/home/.pi/agent/extensions/openai-fast-mode.ts" ]]
[[ "$(readlink "$fixture/home/.pi/agent/extensions/remember-model.ts")" == "$repo_dir/dot/.pi/agent/extensions/remember-model.ts" ]]
[[ -L "$fixture/home/.config/zed/settings.json" ]]
jq -e 'has("agent_servers") == false and .diff_view_style == "split" and
    .terminal.font_family == "Hack Nerd Font"' \
    "$fixture/home/.config/zed/settings.json" >/dev/null

for agents_link in .claude/AGENTS.md .codex/AGENTS.md .pi/agent/AGENTS.md; do
    [[ -L "$fixture/home/$agents_link" ]]
    [[ "$(readlink "$fixture/home/$agents_link")" == "$repo_dir/dot/AGENTS.md" ]]
done
grep -Fq '@~/.claude/AGENTS.md' "$fixture/home/.claude/CLAUDE.md"

for agent in "${omp_agents[@]}"; do
    agent_dir="$fixture/home/$agent"
    for retired in config.yml AGENTS.md themes/seashells.json themes/seashells-light.json; do
        [[ ! -e "$agent_dir/$retired" && ! -L "$agent_dir/$retired" ]]
    done
    [[ -d "$agent_dir" && ! -L "$agent_dir" ]]
    [[ -d "$agent_dir/themes" && ! -L "$agent_dir/themes" ]]
    grep -Fxq 'machine-runtime' "$agent_dir/agent.db"
    [[ ! -L "$agent_dir/agent.db" ]]
    grep -Fxq 'machine-session' "$agent_dir/sessions/session.json"
    grep -Fxq 'old: machine settings' "$agent_dir/config.yml.old"
done
grep -Fxq 'personal: settings' "$fixture/home/.omp/profiles/personal/agent/config.yml"
[[ ! -e "$repo_dir/dot/.omp" ]]

# Replacement machine-owned configs and unrelated symlinks must not be removed.
printf 'machine: settings\n' >"$fixture/home/.omp/agent/config.yml"
printf 'machine: theme\n' >"$fixture/home/.omp/agent/themes/seashells.json"
printf 'external: settings\n' >"$fixture/external.yml"
ln -s "$fixture/external.yml" "$fixture/home/.omp/profiles/work/agent/config.yml"
ln -s "$fixture/missing.json" "$fixture/home/.omp/profiles/work/agent/themes/seashells.json"
ln -s '../../../../../external.yml' "$fixture/home/.omp/profiles/deepseek/agent/config.yml"
for _ in 1 2; do
    HOME="$fixture/home" PATH="/usr/bin:/bin" "$repo_dir/link-dotfiles.sh"
done
grep -Fxq 'machine: settings' "$fixture/home/.omp/agent/config.yml"
grep -Fxq 'machine: theme' "$fixture/home/.omp/agent/themes/seashells.json"
[[ "$(readlink "$fixture/home/.omp/profiles/work/agent/config.yml")" == "$fixture/external.yml" ]]
grep -Fxq 'external: settings' "$fixture/external.yml"
[[ "$(readlink "$fixture/home/.omp/profiles/work/agent/themes/seashells.json")" == "$fixture/missing.json" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/deepseek/agent/config.yml")" == '../../../../../external.yml' ]]

# A fresh home gets Pi configuration without creating any OMP profile directory.
HOME="$fixture/fresh-home" PATH="/usr/bin:/bin" "$repo_dir/link-dotfiles.sh"
[[ ! -e "$fixture/fresh-home/.omp" ]]
jq -e '.theme == "seashells"' "$fixture/fresh-home/.pi/agent/settings.json" >/dev/null
[[ -L "$fixture/fresh-home/.pi/agent/themes/seashells.json" ]]
[[ -L "$fixture/fresh-home/.pi/agent/themes/seashells-light.json" ]]

# Linking is local-only: generated repositories and plugin directories are not created.
[[ ! -e "$fixture/home/.config/nvim" ]]
[[ ! -e "$fixture/home/.tmux/plugins/tpm" ]]

# Invalid Pi JSON fails without truncating or replacing the original file.
printf '{invalid json\n' >"$fixture/home/.pi/agent/settings.json"
if HOME="$fixture/home" "$repo_dir/link-dotfiles.sh" >/dev/null 2>&1; then
    echo "Invalid Pi settings unexpectedly succeeded." >&2
    exit 1
fi
grep -Fxq '{invalid json' "$fixture/home/.pi/agent/settings.json"

printf 'Full dotfile linking contracts passed.\n'
