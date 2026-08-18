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

_git_github_identity() {
    local url="$1" path owner repository extra
    case "$url" in
        https://github.com/*) path=${url#https://github.com/} ;;
        http://github.com/*) path=${url#http://github.com/} ;;
        git@github.com:*) path=${url#git@github.com:} ;;
        ssh://git@github.com/*) path=${url#ssh://git@github.com/} ;;
        *) return 1 ;;
    esac
    path=${path%/}
    path=${path%.git}
    IFS=/ read -r owner repository extra <<<"$path"
    [[ -n "$owner" && -n "$repository" && -z "${extra:-}" ]] || return 1
    [[ "$owner" =~ ^[A-Za-z0-9_.-]+$ && "$repository" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
    printf 'github.com/%s/%s\n' "$owner" "$repository"
}

_git_origin_matches() {
    local checkout="$1"
    local expected_url="$2"
    local actual_url actual_identity expected_identity

    actual_url=$(git -C "$checkout" remote get-url origin) || return 1
    if [[ "${actual_url%.git}" != "${expected_url%.git}" ]]; then
        actual_identity=$(_git_github_identity "$actual_url" || true)
        expected_identity=$(_git_github_identity "$expected_url" || true)
        if [[ -z "$actual_identity" || "$actual_identity" != "$expected_identity" ]]; then
            printf 'Unexpected origin for %s\nExpected: %s\nActual:   %s\n' \
                "$checkout" "$expected_url" "$actual_url" >&2
            return 1
        fi
    fi
}

git_ff() {
    local dest="$1"
    local expected_url="${2:-}"
    local expected_branch="${3:-}"
    local nested_path="${4:-}"
    local nested_url="${5:-}"
    local current_branch nested_status status

    status=$(git -C "$dest" status --porcelain) || return 1
    if [[ -n "$nested_path" && "$status" == "?? $nested_path/" ]]; then
        # A deliberately nested checkout is untracked by its parent. Accept it
        # only when it is itself clean and has the exact expected origin.
        if [[ -z "$nested_url" || ! -d "$dest/$nested_path/.git" ]]; then
            echo "Invalid managed nested checkout: $dest/$nested_path" >&2
            return 1
        fi
        nested_status=$(git -C "$dest/$nested_path" status --porcelain) || return 1
        if [[ -n "$nested_status" ]] ||
            ! _git_origin_matches "$dest/$nested_path" "$nested_url"; then
            echo "Invalid managed nested checkout: $dest/$nested_path" >&2
            return 1
        fi
        status=""
    fi
    if [[ -n "$status" ]]; then
        echo "Cannot update modified checkout: $dest" >&2
        git -C "$dest" status --short >&2
        return 1
    fi
    if [[ -n "$expected_url" ]]; then
        _git_origin_matches "$dest" "$expected_url" || return 1
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

_clone_or_ff() {
    local url="$1" dest="$2" branch="$3"
    local nested_path="$4" nested_url="$5"

    if [[ -d "$dest/.git" ]]; then
        git_ff "$dest" "$url" "$branch" "$nested_path" "$nested_url"
    elif [[ -e "$dest" ]]; then
        echo "Cannot clone over existing path: $dest" >&2
        return 1
    elif [[ -n "$branch" ]]; then
        _git_retry "Cloning $url" git clone --branch "$branch" "$url" "$dest"
    else
        _git_retry "Cloning $url" git clone "$url" "$dest"
    fi
}

clone_or_ff() {
    _clone_or_ff "$1" "$2" "${3:-}" "" ""
}

clone_or_ff_with_nested() {
    if (($# != 5)); then
        echo "clone_or_ff_with_nested requires URL, destination, branch, nested path, and nested URL" >&2
        return 2
    fi
    _clone_or_ff "$1" "$2" "$3" "$4" "$5"
}
