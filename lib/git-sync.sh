#!/usr/bin/env bash
# Reusable git helpers for keeping cloned repos current across machines.
#
# Source this file, then use:
#   clone_or_ff <url> <dest> [branch]   # clone if missing, else fast-forward
#   git_ff <dir>                        # fast-forward an existing clone
#
# Both are NON-DESTRUCTIVE: if the worktree has uncommitted changes or the
# branch has diverged from upstream, they print a note and leave the repo
# untouched (return 0) rather than clobbering local work. They return nonzero
# only on a real failure (clone/fetch error), so callers can surface that.
#
# Works when sourced from either bash or zsh.

_git_retry() {
    local label="$1"
    shift
    local attempt

    for attempt in 1 2 3; do
        if "$@"; then
            return 0
        fi
        if (( attempt < 3 )); then
            echo "$label failed (attempt $attempt/3); retrying..." >&2
            sleep $((attempt * 2))
        fi
    done

    echo "$label failed after 3 attempts." >&2
    return 1
}

# Fast-forward an existing clone to its tracked upstream.
git_ff() {
    local dir="$1"
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        echo "skip: uncommitted changes in $dir"
        return 0
    fi
    _git_retry "fetching $dir" git -C "$dir" fetch --quiet origin || return 1
    local branch
    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
    git -C "$dir" merge --ff-only --quiet "origin/$branch" 2>/dev/null \
        || echo "skip: $dir has diverged from origin/$branch (rebase manually)"
    return 0
}

# Clone <url> into <dest> if absent (optionally tracking <branch>); otherwise
# fast-forward the existing clone via git_ff.
clone_or_ff() {
    local url="$1" dest="$2" branch="${3:-}"
    if [ ! -d "$dest/.git" ]; then
        if [ -n "$branch" ]; then
            _git_retry "cloning $url" git clone "$url" "$dest" -b "$branch"
        else
            _git_retry "cloning $url" git clone "$url" "$dest"
        fi
        return
    fi
    git_ff "$dest"
}
