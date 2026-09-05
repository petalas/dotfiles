#!/usr/bin/env bash
# Keep the petalas/nvim fork synchronized with nvim-lua/kickstart.nvim.
# Safe to source from Bash or Zsh.

_nvim_sync_prune_legacy_lazy_lock() {
    local dir="$1"
    local lazy_lock_status

    if [ ! -f "$dir/lazy-lock.json" ]; then
        return 0
    fi
    if git -C "$dir" ls-files --error-unmatch lazy-lock.json >/dev/null 2>&1; then
        return 0
    fi
    if ! git -C "$dir" ls-files --error-unmatch nvim-pack-lock.json >/dev/null 2>&1; then
        return 0
    fi

    lazy_lock_status=$(git -C "$dir" status --porcelain --untracked-files=all -- lazy-lock.json) || return 1
    if [ "$lazy_lock_status" = "?? lazy-lock.json" ]; then
        echo "nvim sync: removing obsolete untracked lazy-lock.json"
        rm -f "$dir/lazy-lock.json" || return 1
    fi
}

_nvim_sync_ensure_github_auth() {
    local dir="$1"
    local origin_url

    origin_url=$(git -C "$dir" remote get-url origin) || return 1
    case "$origin_url" in
        https://github.com/*|http://github.com/*) ;;
        *) return 0 ;;
    esac

    if ! command -v gh >/dev/null 2>&1; then
        echo "nvim sync: GitHub CLI (gh) is required for the GitHub fork" >&2
        return 1
    fi

    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ] || [ ! -t 0 ]; then
            echo "nvim sync: authenticate first with 'gh auth login --hostname github.com --git-protocol https --web'" >&2
            return 1
        fi
        echo "GitHub CLI is not authenticated; starting browser login..."
        gh auth login --hostname github.com --git-protocol https --web || return 1
        gh auth status --hostname github.com >/dev/null 2>&1 || {
            echo "nvim sync: GitHub CLI authentication did not complete" >&2
            return 1
        }
    fi
}

_nvim_sync_git_network() {
    local dir="$1"
    shift

    # Scope the credential helper to this command. ~/.gitconfig is a managed
    # dotfile, so `gh auth setup-git` would dirty this repository and bake the
    # current machine's gh path into shared configuration.
    env GIT_TERMINAL_PROMPT=0 git \
        -c credential.https://github.com.helper= \
        -c 'credential.https://github.com.helper=!gh auth git-credential' \
        -C "$dir" "$@"
}

_nvim_sync_resolve_binary() {
    local managed="${XDG_DATA_HOME:-$HOME/.local/share}/nvim-nightly/bin/nvim"
    if [ -x "$managed" ]; then
        printf '%s\n' "$managed"
    else
        command -v nvim 2>/dev/null
    fi
}

_nvim_sync_require_compatible() {
    local probe
    probe=$("$1" --clean --headless \
        '+lua io.stdout:write("NVIM_PACK_COMPAT=" .. type(vim.pack) .. ":" .. vim.fn.exists("##PackChanged"))' \
        +qa 2>/dev/null) || return 1
    [ "$probe" = NVIM_PACK_COMPAT=table:1 ]
}

_nvim_sync_smoke_config() {
    "$1" --headless \
        '+lua if vim.v.errmsg ~= "" or not vim.g.colors_name then vim.cmd("cquit 1") end' \
        +qa
}

nvim_sync_fork() {
    local dir="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
    local upstream_url="https://github.com/nvim-lua/kickstart.nvim.git"
    local branch="custom"
    local mode="${2:-upstream}"
    case "$mode" in upstream|config) ;; *) echo "nvim sync: invalid mode: $mode" >&2; return 2 ;; esac
    local counts ahead behind nvim_bin

    if [ ! -d "$dir/.git" ]; then
        echo "nvim sync: not a git repository: $dir" >&2
        return 1
    fi
    _nvim_sync_prune_legacy_lazy_lock "$dir" || return 1
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

    if [ "${NVIM_SYNC_SKIP_SMOKE:-0}" != "1" ]; then
        nvim_bin=$(_nvim_sync_resolve_binary || true)
        if [ -n "$nvim_bin" ] && ! _nvim_sync_require_compatible "$nvim_bin"; then
            echo "nvim sync: $nvim_bin lacks the vim.pack APIs required by the config" >&2
            return 1
        fi
    fi

    _nvim_sync_ensure_github_auth "$dir" || return 1

    echo "Fetching nvim fork and Kickstart upstream..."
    _nvim_sync_git_network "$dir" fetch --quiet origin || return 1
    if ! _nvim_sync_git_network "$dir" fetch --quiet upstream; then
        [ "$mode" = config ] || return 1
        echo "Kickstart update check unavailable; continuing with the maintained configuration." >&2
    fi

    counts=$(git -C "$dir" rev-list --left-right --count "$branch...origin/$branch") || return 1
    ahead=$(printf '%s' "$counts" | awk '{ print $1 }')
    behind=$(printf '%s' "$counts" | awk '{ print $2 }')

    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        echo "nvim sync: $branch has diverged from origin/$branch" >&2
        return 1
    elif [ "$behind" -gt 0 ]; then
        git -C "$dir" merge --ff-only --quiet "origin/$branch" || return 1
    fi

    # Test the resolved branch regardless of whether changes came from this
    # machine or were fast-forwarded from another one.
    if [ -n "${nvim_bin:-}" ] && [ "${NVIM_SYNC_SKIP_SMOKE:-0}" != "1" ]; then
        _nvim_sync_smoke_config "$nvim_bin" || {
            echo "nvim sync: resolved config failed the startup smoke test" >&2
            return 1
        }
    fi
    if [ "$ahead" -gt 0 ]; then
        echo "Pushing previously committed nvim changes..."
        _nvim_sync_git_network "$dir" push origin "$branch" || return 1
    fi

    if [ "$mode" = config ]; then
        if ! git -C "$dir" merge-base --is-ancestor upstream/master "$branch"; then
            echo "Kickstart changes pending review; run sync-nvim to integrate them."
        fi
        return 0
    fi

    if git -C "$dir" show-ref --verify --quiet refs/remotes/origin/master &&
        ! git -C "$dir" merge-base --is-ancestor origin/master upstream/master; then
        echo "nvim sync: origin/master diverged from upstream/master" >&2
        return 1
    fi

    echo "Updating the fork's master mirror..."
    _nvim_sync_git_network "$dir" push --quiet origin refs/remotes/upstream/master:refs/heads/master || return 1
    _nvim_sync_git_network "$dir" fetch --quiet origin master || return 1

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

    if [ -n "${nvim_bin:-}" ] && [ "${NVIM_SYNC_SKIP_SMOKE:-0}" != "1" ]; then
        if ! _nvim_sync_smoke_config "$nvim_bin"; then
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

    if ! git -C "$dir" commit -m "Merge upstream kickstart.nvim master"; then
        git -C "$dir" merge --abort >/dev/null 2>&1 || true
        echo "nvim sync: could not create the upstream merge commit" >&2
        return 1
    fi
    _nvim_sync_git_network "$dir" push origin "$branch" || return 1
    echo "nvim fork and custom config are up to date."
}

nvim_update_plugins() {
    local dir="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
    local changed config_home nvim_bin

    if [ ! -d "$dir/.git" ]; then
        echo "nvim plugins: not a git repository: $dir" >&2
        return 1
    fi
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        echo "nvim plugins: refusing to update with a dirty config worktree" >&2
        return 1
    fi
    if [ "$(git -C "$dir" branch --show-current)" != custom ]; then
        echo "nvim plugins: expected branch 'custom' in $dir" >&2
        return 1
    fi
    nvim_bin=$(_nvim_sync_resolve_binary || true)
    if [ -z "$nvim_bin" ]; then
        echo "nvim plugins: nvim is not installed" >&2
        return 1
    fi
    if ! _nvim_sync_require_compatible "$nvim_bin"; then
        echo "nvim plugins: $nvim_bin lacks the vim.pack APIs required by the config" >&2
        return 1
    fi

    config_home=${dir%/nvim}
    XDG_CONFIG_HOME="$config_home" "$nvim_bin" --headless \
        '+lua local ok, err = xpcall(function() vim.pack.update(nil, { force = true }) end, debug.traceback); if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") end' \
        '+lua local ok, err = xpcall(function() require("nvim-treesitter").update():wait(300000) end, debug.traceback); if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") end' \
        +qa || return 1

    changed=$(git -C "$dir" status --porcelain)
    if [ -z "$changed" ]; then
        echo "nvim plugins already up to date."
        return 0
    fi
    if [ "$(printf '%s\n' "$changed" | awk '{ print $2 }' | sort -u)" != "nvim-pack-lock.json" ]; then
        echo "nvim plugins: update changed files other than nvim-pack-lock.json; restoring the clean checkout" >&2
        printf '%s\n' "$changed" >&2
        git -C "$dir" reset --hard HEAD >/dev/null || return 1
        git -C "$dir" clean -fd >/dev/null || return 1
        return 1
    fi

    git -C "$dir" add -- nvim-pack-lock.json || return 1
    if ! git -C "$dir" commit -m "chore(nvim): update plugin lockfile"; then
        git -C "$dir" reset --hard HEAD >/dev/null 2>&1 || true
        return 1
    fi
    _nvim_sync_ensure_github_auth "$dir" || return 1
    _nvim_sync_git_network "$dir" push origin custom || return 1
    echo "Updated and published the nvim plugin lockfile."
}
