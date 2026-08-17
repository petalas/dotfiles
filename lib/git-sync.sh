#!/usr/bin/env bash

_git_retry() {
    local label="$1" attempt
    shift
    for attempt in 1 2 3; do
        "$@" && return 0
        ((attempt == 3)) || sleep "$attempt"
    done
    echo "$label failed after 3 attempts." >&2
    return 1
}

git_ff() {
    local dest="$1"
    local expected_url="${2:-}"
    local expected_branch="${3:-}"
    local actual_url current_branch

    if [[ -n "$(git -C "$dest" status --porcelain)" ]]; then
        echo "Cannot update modified checkout: $dest" >&2
        git -C "$dest" status --short >&2
        return 1
    fi
    if [[ -n "$expected_url" ]]; then
        actual_url=$(git -C "$dest" remote get-url origin) || return 1
        if [[ "${actual_url%.git}" != "${expected_url%.git}" ]]; then
            printf 'Unexpected origin for %s\nExpected: %s\nActual:   %s\n' \
                "$dest" "$expected_url" "$actual_url" >&2
            return 1
        fi
    fi
    if [[ -n "$expected_branch" ]]; then
        current_branch=$(git -C "$dest" branch --show-current) || return 1
        if [[ "$current_branch" != "$expected_branch" ]]; then
            printf 'Unexpected branch for %s: expected %s, found %s\n' \
                "$dest" "$expected_branch" "${current_branch:-detached HEAD}" >&2
            return 1
        fi
    fi
    _git_retry "Updating $dest" git -C "$dest" pull --ff-only --quiet
}

clone_or_ff() {
    local url="$1" dest="$2" branch="${3:-}"
    if [[ -d "$dest/.git" ]]; then
        git_ff "$dest" "$url" "$branch"
    elif [[ -e "$dest" ]]; then
        echo "Cannot clone over existing path: $dest" >&2
        return 1
    elif [[ -n "$branch" ]]; then
        _git_retry "Cloning $url" git clone --branch "$branch" "$url" "$dest"
    else
        _git_retry "Cloning $url" git clone "$url" "$dest"
    fi
}
