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
printf '{}\n' > "$seed/nvim-pack-lock.json"
git -C "$seed" add shared.txt nvim-pack-lock.json
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

# A stale lazy.nvim lockfile left behind by the vim.pack migration is safe to
# prune before the dirty-worktree guard. Unknown untracked files still block.
printf '{}\n' > "$config/lazy-lock.json"
NVIM_SYNC_SKIP_SMOKE=1 nvim_sync_fork "$config"
[[ ! -e "$config/lazy-lock.json" ]]
[[ -z "$(git -C "$config" status --porcelain)" ]]

printf 'scratch\n' > "$config/scratch.txt"
if NVIM_SYNC_SKIP_SMOKE=1 nvim_sync_fork "$config"; then
    echo 'nvim sync unexpectedly accepted an unknown untracked file' >&2
    exit 1
fi
rm -f "$config/scratch.txt"

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

# Routine updates leave conflicting upstream changes pending and still succeed.
NVIM_SYNC_SKIP_SMOKE=1 nvim_sync_fork "$config" config >"$fixture/pending"
grep -Fq 'Kickstart changes pending review' "$fixture/pending"
[[ "$(git -C "$config" rev-parse custom)" == "$custom_before_conflict" ]]
[[ -z "$(git -C "$config" status --porcelain)" ]]

if NVIM_SYNC_SKIP_SMOKE=1 nvim_sync_fork "$config"; then
    echo 'nvim sync unexpectedly accepted a conflicting merge' >&2
    exit 1
fi
[[ "$(git -C "$config" rev-parse custom)" == "$custom_before_conflict" ]]
[[ -z "$(git -C "$config" status --porcelain)" ]]
[[ "$(git --git-dir="$fork" rev-parse master)" == "$(git --git-dir="$upstream" rev-parse master)" ]]

# Plugin updates never publish from an unexpected branch.
git -C "$config" checkout --quiet master
if nvim_update_plugins "$config"; then
    echo 'nvim plugin update unexpectedly accepted master' >&2
    exit 1
fi
git -C "$config" checkout --quiet custom

# Plugin reconciliation explicitly uses the managed nightly even when an older
# distro nvim appears first on PATH.
managed_home="$fixture/home"
managed_nvim="$managed_home/.local/share/nvim-nightly/bin/nvim"
nvim_log="$fixture/nvim.log"
mkdir -p "${managed_nvim%/*}"
cat >"$managed_nvim" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NVIM_TEST_LOG"
if [[ $* == *NVIM_PACK_COMPAT* ]]; then printf 'NVIM_PACK_COMPAT=table:1'; fi
exit 0
EOF
chmod +x "$managed_nvim"
HOME="$managed_home" NVIM_TEST_LOG="$nvim_log" nvim_update_plugins "$config"
grep -Fq -- '--clean --headless' "$nvim_log"
grep -Fq 'vim.pack.update' "$nvim_log"
grep -Fq 'xpcall' "$nvim_log"

echo 'Nvim fork synchronization tests passed.'
