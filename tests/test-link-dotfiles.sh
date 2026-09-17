#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-link-all.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
# Writes through linked preferences must never touch the real checkout.
git init -q "$fixture/repo"
cp -R "$repo_dir/dot" "$repo_dir/lib" "$repo_dir/link-dotfiles.sh" "$fixture/repo/"
repo_dir="$fixture/repo"
# Distinguishable fixture OMP sources: profile independence is proven through
# these markers, never through incidental model strings.
[[ -f "$repo_dir/dot/.omp/agent/config-deepseek.yml" ]]
[[ -f "$repo_dir/dot/.omp/agent/config-free.yml" ]]
printf 'profile: default-fixture\n' >"$repo_dir/dot/.omp/agent/config.yml"
printf 'profile: work-fixture\n' >"$repo_dir/dot/.omp/agent/config-work.yml"
printf 'profile: deepseek-fixture\n' >"$repo_dir/dot/.omp/agent/config-deepseek.yml"
printf 'profile: free-fixture\n' >"$repo_dir/dot/.omp/agent/config-free.yml"
mkdir -p "$fixture/home/.ssh" "$fixture/home/.pi/agent" \
    "$fixture/home/.omp/agent" \
    "$fixture/home/.omp/profiles/work/agent" \
    "$fixture/home/.omp/profiles/cheap/agent" \
    "$fixture/home/.omp/profiles/free/agent" \
    "$fixture/home/git/notes"
printf '# Include ~/.ssh/config.shared\nHost example\n' >"$fixture/home/.ssh/config"
printf '{"defaultModel":"test"}\n' >"$fixture/home/.pi/agent/settings.json"
mkdir -p "$fixture/home/.claude"
printf '{"theme":"dark"}\n' >"$fixture/home/.claude/settings.json"
# Pre-existing regular configs: each profile must keep its prior content as .old.
# The cheap profile stands in for legacy state left by the previous profile name;
# the linker renames that directory to deepseek with its runtime state intact.
printf 'old: default settings\n' >"$fixture/home/.omp/agent/config.yml"
printf 'old: work settings\n' >"$fixture/home/.omp/profiles/work/agent/config.yml"
printf 'old: cheap settings\n' >"$fixture/home/.omp/profiles/cheap/agent/config.yml"
printf 'old: free settings\n' >"$fixture/home/.omp/profiles/free/agent/config.yml"
# Fixture-only runtime sentinels. These stand in for machine-local databases,
# sessions, and caches; this test never opens real OMP SQLite files.
mkdir -p "$fixture/home/.omp/agent/sessions" \
    "$fixture/home/.omp/profiles/work/agent/sessions" \
    "$fixture/home/.omp/profiles/cheap/agent/sessions" \
    "$fixture/home/.omp/profiles/free/agent/sessions"
printf 'default-runtime\n' >"$fixture/home/.omp/agent/agent.db"
printf 'work-runtime\n' >"$fixture/home/.omp/profiles/work/agent/agent.db"
printf 'cheap-runtime\n' >"$fixture/home/.omp/profiles/cheap/agent/agent.db"
printf 'free-runtime\n' >"$fixture/home/.omp/profiles/free/agent/agent.db"
printf 'default-session\n' >"$fixture/home/.omp/agent/sessions/session.json"
# Links older revisions created for the retired global commands, plus a
# user-owned command that must survive the prune.
mkdir -p "$fixture/home/.claude/commands"
ln -s "$repo_dir/dot/claude/commands/knowledge-audit.md" \
    "$fixture/home/.claude/commands/knowledge-audit.md"
ln -s "$repo_dir/dot/claude/commands/knowledge-migrate-all.md" \
    "$fixture/home/.claude/commands/knowledge-migrate-all.md"
ln -s "$fixture/home/own-command.md" "$fixture/home/.claude/commands/own-command.md"
for _ in 1 2; do
    HOME="$fixture/home" PATH="/usr/bin:/bin" \
        "$repo_dir/link-dotfiles.sh"
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
jq -e '.autoMemoryEnabled == false and .theme == "dark"' \
    "$fixture/home/.claude/settings.json" >/dev/null
[[ ! -L "$fixture/home/.claude/settings.json" ]]

# OMP native profiles: the default agent dir plus the work/deepseek/free named
# dirs. The legacy cheap directory is renamed in place before linking, so its old
# config is still the one backed up beside the newly linked deepseek config.
grep -Fxq 'old: default settings' "$fixture/home/.omp/agent/config.yml.old"
[[ ! -L "$fixture/home/.omp/agent/config.yml.old" ]]
[[ -L "$fixture/home/.omp/agent/config.yml" ]]
[[ "$(readlink "$fixture/home/.omp/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config.yml" ]]
grep -Fxq 'profile: default-fixture' "$fixture/home/.omp/agent/config.yml"
grep -Fxq 'old: work settings' "$fixture/home/.omp/profiles/work/agent/config.yml.old"
[[ ! -L "$fixture/home/.omp/profiles/work/agent/config.yml.old" ]]
[[ -L "$fixture/home/.omp/profiles/work/agent/config.yml" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/work/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-work.yml" ]]
grep -Fxq 'profile: work-fixture' "$fixture/home/.omp/profiles/work/agent/config.yml"
[[ ! -e "$fixture/home/.omp/profiles/cheap" ]]
grep -Fxq 'old: cheap settings' "$fixture/home/.omp/profiles/deepseek/agent/config.yml.old"
[[ ! -L "$fixture/home/.omp/profiles/deepseek/agent/config.yml.old" ]]
[[ -L "$fixture/home/.omp/profiles/deepseek/agent/config.yml" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/deepseek/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-deepseek.yml" ]]
grep -Fxq 'profile: deepseek-fixture' "$fixture/home/.omp/profiles/deepseek/agent/config.yml"
grep -Fxq 'old: free settings' "$fixture/home/.omp/profiles/free/agent/config.yml.old"
[[ ! -L "$fixture/home/.omp/profiles/free/agent/config.yml.old" ]]
[[ -L "$fixture/home/.omp/profiles/free/agent/config.yml" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/free/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-free.yml" ]]
grep -Fxq 'profile: free-fixture' "$fixture/home/.omp/profiles/free/agent/config.yml"

# Only files are linked; no whole-profile or agent directory is a symlink.
[[ ! -L "$fixture/home/.omp/agent" ]]
[[ ! -L "$fixture/home/.omp/profiles" ]]
[[ ! -L "$fixture/home/.omp/profiles/work" ]]
[[ ! -L "$fixture/home/.omp/profiles/work/agent" ]]
[[ ! -L "$fixture/home/.omp/profiles/deepseek" ]]
[[ ! -L "$fixture/home/.omp/profiles/deepseek/agent" ]]
[[ ! -L "$fixture/home/.omp/profiles/free" ]]
[[ ! -L "$fixture/home/.omp/profiles/free/agent" ]]

[[ -L "$fixture/home/.pi/agent/themes/seashells.json" ]]
[[ -L "$fixture/home/.pi/agent/themes/seashells-light.json" ]]

# Shared themes are linked into every profile dir; theme dirs stay real.
for profile_agent in .omp/agent .omp/profiles/work/agent .omp/profiles/deepseek/agent .omp/profiles/free/agent; do
    [[ ! -L "$fixture/home/$profile_agent/themes" ]]
    [[ -L "$fixture/home/$profile_agent/themes/seashells.json" ]]
    [[ "$(readlink "$fixture/home/$profile_agent/themes/seashells.json")" == "$repo_dir/dot/.omp/agent/themes/seashells.json" ]]
    [[ -L "$fixture/home/$profile_agent/themes/seashells-light.json" ]]
    [[ "$(readlink "$fixture/home/$profile_agent/themes/seashells-light.json")" == "$repo_dir/dot/.omp/agent/themes/seashells-light.json" ]]
done

# Global AGENTS.md is linked into every profile agent dir.
for agents_link in .claude/AGENTS.md .codex/AGENTS.md .pi/agent/AGENTS.md .omp/agent/AGENTS.md .omp/profiles/work/agent/AGENTS.md .omp/profiles/deepseek/agent/AGENTS.md .omp/profiles/free/agent/AGENTS.md; do
    [[ -L "$fixture/home/$agents_link" ]]
    [[ "$(readlink "$fixture/home/$agents_link")" == "$repo_dir/dot/AGENTS.md" ]]
done
grep -Fq '@~/.claude/AGENTS.md' "$fixture/home/.claude/CLAUDE.md"
[[ ! -L "$fixture/home/.claude/commands/knowledge-audit.md" ]]
[[ ! -L "$fixture/home/.claude/commands/knowledge-migrate-all.md" ]]
[[ -L "$fixture/home/.claude/commands/own-command.md" ]]

# Linking is local-only: generated repositories and plugin directories are not created.
[[ ! -e "$fixture/home/.config/nvim" ]]
[[ ! -e "$fixture/home/.tmux/plugins/tpm" ]]

# Machine-local runtime state is untouched: sentinels keep their content, stay
# regular files, and are never copied into the checkout.
grep -Fxq 'default-runtime' "$fixture/home/.omp/agent/agent.db"
[[ ! -L "$fixture/home/.omp/agent/agent.db" ]]
grep -Fxq 'work-runtime' "$fixture/home/.omp/profiles/work/agent/agent.db"
[[ ! -L "$fixture/home/.omp/profiles/work/agent/agent.db" ]]
grep -Fxq 'cheap-runtime' "$fixture/home/.omp/profiles/deepseek/agent/agent.db"
[[ ! -L "$fixture/home/.omp/profiles/deepseek/agent/agent.db" ]]
grep -Fxq 'free-runtime' "$fixture/home/.omp/profiles/free/agent/agent.db"
[[ ! -L "$fixture/home/.omp/profiles/free/agent/agent.db" ]]
grep -Fxq 'default-session' "$fixture/home/.omp/agent/sessions/session.json"
[[ ! -e "$repo_dir/dot/.omp/agent/agent.db" ]]
[[ ! -e "$repo_dir/dot/.omp/agent/sessions/session.json" ]]

# Writes through each linked profile reach only their own backing file.
printf 'profile: default-write\n' >"$fixture/home/.omp/agent/config.yml"
grep -Fxq 'profile: default-write' "$repo_dir/dot/.omp/agent/config.yml"
grep -Fxq 'profile: work-fixture' "$repo_dir/dot/.omp/agent/config-work.yml"
grep -Fxq 'profile: deepseek-fixture' "$repo_dir/dot/.omp/agent/config-deepseek.yml"
grep -Fxq 'profile: free-fixture' "$repo_dir/dot/.omp/agent/config-free.yml"
printf 'profile: work-write\n' >"$fixture/home/.omp/profiles/work/agent/config.yml"
grep -Fxq 'profile: work-write' "$repo_dir/dot/.omp/agent/config-work.yml"
grep -Fxq 'profile: default-write' "$repo_dir/dot/.omp/agent/config.yml"
grep -Fxq 'profile: deepseek-fixture' "$repo_dir/dot/.omp/agent/config-deepseek.yml"
grep -Fxq 'profile: free-fixture' "$repo_dir/dot/.omp/agent/config-free.yml"
printf 'profile: deepseek-write\n' >"$fixture/home/.omp/profiles/deepseek/agent/config.yml"
grep -Fxq 'profile: deepseek-write' "$repo_dir/dot/.omp/agent/config-deepseek.yml"
grep -Fxq 'profile: default-write' "$repo_dir/dot/.omp/agent/config.yml"
grep -Fxq 'profile: work-write' "$repo_dir/dot/.omp/agent/config-work.yml"
grep -Fxq 'profile: free-fixture' "$repo_dir/dot/.omp/agent/config-free.yml"
printf 'profile: free-write\n' >"$fixture/home/.omp/profiles/free/agent/config.yml"
grep -Fxq 'profile: free-write' "$repo_dir/dot/.omp/agent/config-free.yml"
grep -Fxq 'profile: default-write' "$repo_dir/dot/.omp/agent/config.yml"
grep -Fxq 'profile: work-write' "$repo_dir/dot/.omp/agent/config-work.yml"
grep -Fxq 'profile: deepseek-write' "$repo_dir/dot/.omp/agent/config-deepseek.yml"

# Repeated relinking keeps every profile link, keeps write-through content,
# and leaves the original backups alone.
for _ in 1 2; do
    HOME="$fixture/home" PATH="/usr/bin:/bin" "$repo_dir/link-dotfiles.sh"
done
[[ "$(readlink "$fixture/home/.omp/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config.yml" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/work/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-work.yml" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/deepseek/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-deepseek.yml" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/free/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-free.yml" ]]
grep -Fxq 'profile: default-write' "$fixture/home/.omp/agent/config.yml"
grep -Fxq 'profile: work-write' "$fixture/home/.omp/profiles/work/agent/config.yml"
grep -Fxq 'profile: deepseek-write' "$fixture/home/.omp/profiles/deepseek/agent/config.yml"
grep -Fxq 'profile: free-write' "$fixture/home/.omp/profiles/free/agent/config.yml"
grep -Fxq 'old: default settings' "$fixture/home/.omp/agent/config.yml.old"
grep -Fxq 'old: work settings' "$fixture/home/.omp/profiles/work/agent/config.yml.old"
grep -Fxq 'old: cheap settings' "$fixture/home/.omp/profiles/deepseek/agent/config.yml.old"
grep -Fxq 'old: free settings' "$fixture/home/.omp/profiles/free/agent/config.yml.old"

# Migration from the old work-selected default symlink restores the default
# link, whether the stale symlink is absolute or relative. The replaced link
# is kept once as config.yml.old per link_path semantics; future selection is
# --profile/OMP_PROFILE, not this symlink.
for work_source in "$repo_dir/dot/.omp/agent/config-work.yml" \
    "../../../repo/dot/.omp/agent/config-work.yml"; do
    ln -sfn "$work_source" "$fixture/home/.omp/agent/config.yml"
    HOME="$fixture/home" PATH="/usr/bin:/bin" "$repo_dir/link-dotfiles.sh"
    [[ -L "$fixture/home/.omp/agent/config.yml" ]]
    [[ "$(readlink "$fixture/home/.omp/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config.yml" ]]
    [[ "$(readlink "$fixture/home/.omp/agent/config.yml.old")" == "$work_source" ]]
    grep -Fxq 'profile: default-write' "$fixture/home/.omp/agent/config.yml"
    [[ "$(readlink "$fixture/home/.omp/profiles/work/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-work.yml" ]]
    grep -Fxq 'profile: work-write' "$fixture/home/.omp/profiles/work/agent/config.yml"
    [[ "$(readlink "$fixture/home/.omp/profiles/deepseek/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-deepseek.yml" ]]
    grep -Fxq 'profile: deepseek-write' "$fixture/home/.omp/profiles/deepseek/agent/config.yml"
    [[ "$(readlink "$fixture/home/.omp/profiles/free/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-free.yml" ]]
    grep -Fxq 'profile: free-write' "$fixture/home/.omp/profiles/free/agent/config.yml"
done

# Runtime sentinels still unchanged after every relink and the migration, and the
# renamed profile kept the whole directory tree rather than only its config.
grep -Fxq 'default-runtime' "$fixture/home/.omp/agent/agent.db"
grep -Fxq 'work-runtime' "$fixture/home/.omp/profiles/work/agent/agent.db"
grep -Fxq 'cheap-runtime' "$fixture/home/.omp/profiles/deepseek/agent/agent.db"
[[ -d "$fixture/home/.omp/profiles/deepseek/agent/sessions" ]]
grep -Fxq 'free-runtime' "$fixture/home/.omp/profiles/free/agent/agent.db"
grep -Fxq 'default-session' "$fixture/home/.omp/agent/sessions/session.json"

# A legacy profile that reappears beside the renamed one is ambiguous state, not
# a rename: the linker refuses before touching either directory, so nothing is
# half-moved and the working deepseek profile is left alone.
mkdir -p "$fixture/home/.omp/profiles/cheap/agent"
printf 'stale legacy profile\n' >"$fixture/home/.omp/profiles/cheap/agent/config.yml"
if HOME="$fixture/home" PATH="/usr/bin:/bin" \
    "$repo_dir/link-dotfiles.sh" >/dev/null 2>&1; then
    echo "OMP profile rename collision unexpectedly succeeded." >&2
    exit 1
fi
grep -Fxq 'stale legacy profile' "$fixture/home/.omp/profiles/cheap/agent/config.yml"
[[ ! -L "$fixture/home/.omp/profiles/cheap/agent/config.yml" ]]
[[ "$(readlink "$fixture/home/.omp/profiles/deepseek/agent/config.yml")" == "$repo_dir/dot/.omp/agent/config-deepseek.yml" ]]
grep -Fxq 'profile: deepseek-write' "$fixture/home/.omp/profiles/deepseek/agent/config.yml"
rm -rf "$fixture/home/.omp/profiles/cheap"

# Invalid Pi JSON fails without truncating or replacing the original file.
printf '{invalid json\n' >"$fixture/home/.pi/agent/settings.json"
if HOME="$fixture/home" "$repo_dir/link-dotfiles.sh" >/dev/null 2>&1; then
    echo "Invalid Pi settings unexpectedly succeeded." >&2
    exit 1
fi
grep -Fxq '{invalid json' "$fixture/home/.pi/agent/settings.json"

printf 'Full dotfile linking contracts passed.\n'
