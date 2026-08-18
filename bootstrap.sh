#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: bootstrap.sh [--unattended | --plan FILE]"
}

case "$#" in
    0) ;;
    1)
        case "$1" in
            --unattended) ;;
            --help|-h) usage; exit 0 ;;
            *) usage >&2; exit 2 ;;
        esac
        ;;
    2) [[ "$1" == --plan ]] || { usage >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
esac
installer_args=("$@")

TARGET="${DOTFILES_DIR:-$HOME/git/dotfiles}"
REPO_URL="${DOTFILES_REPO_URL:-https://github.com/petalas/dotfiles.git}"
REPO_BRANCH="${DOTFILES_BRANCH:-main}"
export GIT_TERMINAL_PROMPT=0

retry() {
    local attempt
    for attempt in 1 2 3; do
        "$@" && return 0
        ((attempt == 3)) || sleep "$attempt"
    done
    return 1
}

as_root() {
    if ((EUID == 0)); then
        "$@"
    else
        sudo -n "$@"
    fi
}

case "$(uname -s)" in
    Darwin|Linux) ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
if ((EUID != 0)) && { ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; }; then
    echo "Bootstrap requires working 'sudo -n'; provision it first." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Git not found; installing it..."
    case "$(uname -s)" in
        Darwin)
            echo "Install Xcode Command Line Tools before running bootstrap." >&2
            exit 1
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                apt_frontend=apt-get
                command -v nala >/dev/null 2>&1 && apt_frontend=nala
                command -v apt-fast >/dev/null 2>&1 && apt_frontend=apt-fast
                retry as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
                    "$apt_frontend" update
                retry as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
                    "$apt_frontend" install -y git
            elif command -v pacman >/dev/null 2>&1; then
                retry as_root pacman -Syu --noconfirm --needed git
            else
                echo "Install Git before running bootstrap." >&2
                exit 1
            fi
            ;;
    esac
fi

mkdir -p "$(dirname "$TARGET")"
if [[ -d "$TARGET/.git" ]]; then
    actual_url=$(git -C "$TARGET" remote get-url origin)
    current_branch=$(git -C "$TARGET" branch --show-current)
    if [[ "${actual_url%.git}" != "${REPO_URL%.git}" ]]; then
        printf 'Existing checkout has an unexpected origin.\nExpected: %s\nActual:   %s\n' \
            "$REPO_URL" "$actual_url" >&2
        exit 1
    fi
    if [[ "$current_branch" != "$REPO_BRANCH" ]]; then
        printf 'Existing checkout is on %s; expected %s.\n' \
            "${current_branch:-detached HEAD}" "$REPO_BRANCH" >&2
        exit 1
    fi
    if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
        echo "Uncommitted changes in $TARGET; refusing to pull." >&2
        exit 1
    fi
    echo "Already cloned at $TARGET; syncing origin/$REPO_BRANCH"
    retry git -C "$TARGET" pull --ff-only
elif [[ -e "$TARGET" ]]; then
    echo "Cannot clone over existing non-repository path: $TARGET" >&2
    exit 1
else
    echo "Cloning $REPO_URL -> $TARGET"
    retry git clone --branch "$REPO_BRANCH" "$REPO_URL" "$TARGET"
fi

cd "$TARGET"
exec ./easy-install.sh "${installer_args[@]}"
