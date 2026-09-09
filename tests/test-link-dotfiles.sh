#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-link-all.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home/.ssh" "$fixture/home/.pi/agent" \
    "$fixture/home/.omp/agent" "$fixture/home/git/notes"
printf '# Include ~/.ssh/config.shared\nHost example\n' >"$fixture/home/.ssh/config"
printf '{"defaultModel":"test"}\n' >"$fixture/home/.pi/agent/settings.json"
mkdir -p "$fixture/home/.claude"
printf '{"theme":"dark"}\n' >"$fixture/home/.claude/settings.json"
printf 'old: settings\n' >"$fixture/home/.omp/agent/config.yml"
# Links older revisions created for the retired global commands, plus a
# user-owned command that must survive the prune.
mkdir -p "$fixture/home/.claude/commands"
ln -s "$repo_dir/dot/claude/commands/knowledge-audit.md" \
    "$fixture/home/.claude/commands/knowledge-audit.md"
ln -s "$repo_dir/dot/claude/commands/knowledge-migrate-all.md" \
    "$fixture/home/.claude/commands/knowledge-migrate-all.md"
ln -s "$fixture/home/own-command.md" "$fixture/home/.claude/commands/own-command.md"
cat >"$fixture/bin/omp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$OMP_TEST_LOG"
if [[ "$1 $2 $3" == 'config get modelRoles' ]]; then
    printf '{"value":{"keep":"yes"}}\n'
fi
EOF
chmod +x "$fixture/bin/omp"
: >"$fixture/omp.log"

for _ in 1 2; do
    HOME="$fixture/home" PATH="$fixture/bin:/usr/bin:/bin" OMP_TEST_LOG="$fixture/omp.log" \
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
grep -Fxq 'old: settings' "$fixture/home/.omp/agent/config.yml"
[[ ! -L "$fixture/home/.omp/agent/config.yml" ]]
[[ -L "$fixture/home/.pi/agent/themes/seashells.json" ]]
[[ -L "$fixture/home/.pi/agent/themes/seashells-light.json" ]]
[[ -L "$fixture/home/.omp/agent/themes/seashells.json" ]]
[[ -L "$fixture/home/.omp/agent/themes/seashells-light.json" ]]
for agents_link in .claude/AGENTS.md .codex/AGENTS.md .pi/agent/AGENTS.md .omp/agent/AGENTS.md; do
    [[ -L "$fixture/home/$agents_link" ]]
    [[ "$(readlink "$fixture/home/$agents_link")" == "$repo_dir/dot/AGENTS.md" ]]
done
grep -Fq '@~/.claude/AGENTS.md' "$fixture/home/.claude/CLAUDE.md"
[[ ! -L "$fixture/home/.claude/commands/knowledge-audit.md" ]]
[[ ! -L "$fixture/home/.claude/commands/knowledge-migrate-all.md" ]]
[[ -L "$fixture/home/.claude/commands/own-command.md" ]]
[[ "$(grep -Fxc 'config set theme.dark seashells' "$fixture/omp.log")" == 2 ]]
[[ "$(grep -Fxc 'config set theme.light seashells-light' "$fixture/omp.log")" == 2 ]]
[[ "$(grep -Fxc 'config set statusLine.sessionAccent false' "$fixture/omp.log")" == 2 ]]
grep -Fq 'config set modelRoles {"keep":"yes","default":"openai-codex/gpt-5.6-sol:medium","smol":"openai-codex/gpt-5.6-luna:max","slow":"openai-codex/gpt-5.6-sol:xhigh"}' \
    "$fixture/omp.log"

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
