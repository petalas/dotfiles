#!/usr/bin/env bash
# Keep the petalas/nvim fork synchronized with nvim-lua/kickstart.nvim.
# Safe to source from Bash or Zsh.

nvim_sync_fork() {
    local dir="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
    local upstream_url="https://github.com/nvim-lua/kickstart.nvim.git"
    local branch="custom"
    local counts ahead behind

    if [ ! -d "$dir/.git" ]; then
        echo "nvim sync: not a git repository: $dir" >&2
        return 1
    fi
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        echo "nvim sync: refusing to modify a dirty worktree: $dir" >&2
        git -C "$dir" status --short >&2
        return 1
    fi
    if [ "$(git -C "$dir" branch --show-current)" != "$branch" ]; then
        echo "nvim sync: expected branch '$branch' in $dir" >&2
        return 1
    fi

    if ! git -C "$dir" remote | grep -qx upstream; then
        git -C "$dir" remote add upstream "$upstream_url" || return 1
    fi

    echo "Fetching nvim fork and Kickstart upstream..."
    git -C "$dir" fetch --quiet origin || return 1
    git -C "$dir" fetch --quiet upstream || return 1

    counts=$(git -C "$dir" rev-list --left-right --count "$branch...origin/$branch") || return 1
    ahead=$(printf '%s' "$counts" | awk '{ print $1 }')
    behind=$(printf '%s' "$counts" | awk '{ print $2 }')

    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        echo "nvim sync: $branch has diverged from origin/$branch" >&2
        return 1
    elif [ "$behind" -gt 0 ]; then
        git -C "$dir" merge --ff-only --quiet "origin/$branch" || return 1
    elif [ "$ahead" -gt 0 ]; then
        if command -v nvim >/dev/null 2>&1 && [ "${NVIM_SYNC_SKIP_SMOKE:-0}" != "1" ]; then
            nvim --headless '+lua assert(vim.g.colors_name)' +qa || {
                echo "nvim sync: local commits failed the startup smoke test" >&2
                return 1
            }
        fi
        echo "Pushing previously committed nvim changes..."
        git -C "$dir" push origin "$branch" || return 1
    fi

    if git -C "$dir" show-ref --verify --quiet refs/remotes/origin/master &&
        ! git -C "$dir" merge-base --is-ancestor origin/master upstream/master; then
        echo "nvim sync: origin/master diverged from upstream/master" >&2
        return 1
    fi

    echo "Updating the fork's master mirror..."
    git -C "$dir" push --quiet origin refs/remotes/upstream/master:refs/heads/master || return 1
    git -C "$dir" fetch --quiet origin master || return 1

    if git -C "$dir" merge-base --is-ancestor upstream/master "$branch"; then
        echo "nvim config already contains the latest Kickstart upstream."
        return 0
    fi

    echo "Merging Kickstart upstream into $branch..."
    if ! git -C "$dir" merge --no-ff --no-commit upstream/master; then
        git -C "$dir" merge --abort >/dev/null 2>&1 || true
        echo "nvim sync: upstream has conflicts; merge aborted for manual review" >&2
        return 1
    fi

    if command -v nvim >/dev/null 2>&1 && [ "${NVIM_SYNC_SKIP_SMOKE:-0}" != "1" ]; then
        if ! nvim --headless '+lua assert(vim.g.colors_name)' +qa; then
            git -C "$dir" merge --abort >/dev/null 2>&1 || true
            echo "nvim sync: merged config failed its startup smoke test; merge aborted" >&2
            return 1
        fi
    fi

    if [ -f "$dir/nvim-pack-lock.json" ]; then
        git -C "$dir" add -- nvim-pack-lock.json || return 1
    fi
    if ! git -C "$dir" diff --quiet || [ -n "$(git -C "$dir" ls-files --others --exclude-standard)" ]; then
        git -C "$dir" merge --abort >/dev/null 2>&1 || true
        echo "nvim sync: smoke test produced unexpected worktree changes; merge aborted" >&2
        return 1
    fi

    git -C "$dir" commit -m "Merge upstream kickstart.nvim master" || return 1
    git -C "$dir" push origin "$branch" || return 1
    echo "nvim fork and custom config are up to date."
}

nvim_update_plugins() {
    local dir="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
    local changed

    if [ ! -d "$dir/.git" ]; then
        echo "nvim plugins: not a git repository: $dir" >&2
        return 1
    fi
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        echo "nvim plugins: refusing to update with a dirty config worktree" >&2
        return 1
    fi
    if ! command -v nvim >/dev/null 2>&1; then
        echo "nvim plugins: nvim is not installed" >&2
        return 1
    fi

    nvim --headless \
        '+lua vim.pack.update(nil, { force = true })' \
        '+lua require("nvim-treesitter").update():wait(300000)' \
        +qa || return 1

    changed=$(git -C "$dir" status --porcelain)
    if [ -z "$changed" ]; then
        echo "nvim plugins already up to date."
        return 0
    fi
    if [ "$(printf '%s\n' "$changed" | awk '{ print $2 }' | sort -u)" != "nvim-pack-lock.json" ]; then
        echo "nvim plugins: update changed files other than nvim-pack-lock.json" >&2
        printf '%s\n' "$changed" >&2
        return 1
    fi

    git -C "$dir" add -- nvim-pack-lock.json || return 1
    git -C "$dir" commit -m "chore(nvim): update plugin lockfile" || return 1
    git -C "$dir" push origin custom || return 1
    echo "Updated and published the nvim plugin lockfile."
}
