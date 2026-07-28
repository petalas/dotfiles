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
    if ! git -C "$dest" diff --quiet || ! git -C "$dest" diff --cached --quiet; then
        echo "Skipping modified checkout: $dest"
        return 0
    fi
    _git_retry "Updating $dest" git -C "$dest" pull --ff-only --quiet
}

clone_or_ff() {
    local url="$1" dest="$2" branch="${3:-}"
    if [[ -d "$dest/.git" ]]; then
        git_ff "$dest"
    elif [[ -e "$dest" ]]; then
        echo "Cannot clone over existing path: $dest" >&2
        return 1
    elif [[ -n "$branch" ]]; then
        _git_retry "Cloning $url" git clone --branch "$branch" "$url" "$dest"
    else
        _git_retry "Cloning $url" git clone "$url" "$dest"
    fi
}
