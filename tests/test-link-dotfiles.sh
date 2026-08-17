#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-link-all.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/.ssh" "$fixture/home/.pi/agent"
printf '# Include ~/.ssh/config.shared\nHost example\n' >"$fixture/home/.ssh/config"
printf '{"defaultModel":"test"}\n' >"$fixture/home/.pi/agent/settings.json"

HOME="$fixture/home" "$repo_dir/link-dotfiles.sh"
HOME="$fixture/home" "$repo_dir/link-dotfiles.sh"

[[ -L "$fixture/home/.zshrc" ]]
[[ -L "$fixture/home/.config/yazi" ]]
[[ "$(grep -Ec '^[[:space:]]*Include ~/.ssh/config.shared' "$fixture/home/.ssh/config")" == 1 ]]
[[ "$(stat -c '%a' "$fixture/home/.ssh/config" 2>/dev/null || stat -f '%Lp' "$fixture/home/.ssh/config")" == 600 ]]
jq -e '.theme == "seashells" and .defaultModel == "test"' \
    "$fixture/home/.pi/agent/settings.json" >/dev/null
[[ "$(stat -c '%a' "$fixture/home/.pi/agent/settings.json" 2>/dev/null || stat -f '%Lp' "$fixture/home/.pi/agent/settings.json")" == 600 ]]

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
