#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture=$(mktemp -d /tmp/dotfiles-nvim-sync.XXXXXX)
trap 'rm -rf "$fixture"' EXIT

upstream="$fixture/upstream.git"
fork="$fixture/fork.git"
seed="$fixture/seed"
config="$fixture/nvim"

git init --bare --initial-branch=master "$upstream" >/dev/null
git clone --quiet "$upstream" "$seed"
git -C "$seed" config user.name Test
git -C "$seed" config user.email test@example.com
printf 'base\n' > "$seed/shared.txt"
git -C "$seed" add shared.txt
git -C "$seed" commit --quiet -m base
git -C "$seed" push --quiet origin master

git clone --bare "$upstream" "$fork" >/dev/null 2>&1
git clone --quiet "$fork" "$config"
git -C "$config" config user.name Test
git -C "$config" config user.email test@example.com
git -C "$config" checkout --quiet -b custom
git -C "$config" remote add upstream "$upstream"
printf 'custom\n' > "$config/custom.txt"
git -C "$config" add custom.txt
git -C "$config" commit --quiet -m custom
git -C "$config" push --quiet -u origin custom

printf 'upstream\n' > "$seed/upstream.txt"
git -C "$seed" add upstream.txt
git -C "$seed" commit --quiet -m upstream
git -C "$seed" push --quiet origin master

# shellcheck source=lib/nvim-sync.sh
source "$repo_dir/lib/nvim-sync.sh"
NVIM_SYNC_SKIP_SMOKE=1 nvim_sync_fork "$config"

upstream_head=$(git --git-dir="$upstream" rev-parse master)
[[ "$(git --git-dir="$fork" rev-parse master)" == "$upstream_head" ]]
[[ "$(git --git-dir="$fork" rev-parse custom)" == "$(git -C "$config" rev-parse custom)" ]]
git -C "$config" merge-base --is-ancestor upstream/master custom
[[ "$(git -C "$config" rev-list --parents -n 1 custom | wc -w)" -eq 3 ]]

first_sync=$(git -C "$config" rev-parse custom)
NVIM_SYNC_SKIP_SMOKE=1 nvim_sync_fork "$config"
[[ "$(git -C "$config" rev-parse custom)" == "$first_sync" ]]

# Conflicting upstream changes are aborted and leave the custom worktree clean.
printf 'custom conflict\n' > "$config/shared.txt"
git -C "$config" add shared.txt
git -C "$config" commit --quiet -m custom-conflict
git -C "$config" push --quiet origin custom
custom_before_conflict=$(git -C "$config" rev-parse custom)

printf 'upstream conflict\n' > "$seed/shared.txt"
git -C "$seed" add shared.txt
git -C "$seed" commit --quiet -m upstream-conflict
git -C "$seed" push --quiet origin master

if NVIM_SYNC_SKIP_SMOKE=1 nvim_sync_fork "$config"; then
    echo 'nvim sync unexpectedly accepted a conflicting merge' >&2
    exit 1
fi
[[ "$(git -C "$config" rev-parse custom)" == "$custom_before_conflict" ]]
[[ -z "$(git -C "$config" status --porcelain)" ]]
[[ "$(git --git-dir="$fork" rev-parse master)" == "$(git --git-dir="$upstream" rev-parse master)" ]]

echo 'Nvim fork synchronization tests passed.'
