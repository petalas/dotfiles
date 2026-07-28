#!/usr/bin/env bash
set -euo pipefail

TARGET="${DOTFILES_DIR:-$HOME/git/dotfiles}"
REPO_URL="${DOTFILES_REPO_URL:-https://github.com/petalas/dotfiles.git}"
export GIT_TERMINAL_PROMPT=0

retry() {
    local attempt
    for attempt in 1 2 3; do
        "$@" && return 0
        ((attempt == 3)) || sleep "$attempt"
    done
    return 1
}

configure_bootstrap_pacman() {
    local config=/etc/pacman.conf
    if grep -Eq '^[[:space:]]*#?[[:space:]]*ParallelDownloads[[:space:]]*=' "$config"; then
        sudo -n sed -i -E \
            's/^[[:space:]]*#?[[:space:]]*ParallelDownloads[[:space:]]*=.*/ParallelDownloads = 16/' \
            "$config"
    else
        sudo -n sed -i '/^\[options\]$/a ParallelDownloads = 16' "$config"
    fi
}

if ((EUID != 0)) && ! sudo -n true 2>/dev/null; then
    echo "Bootstrap requires working 'sudo -n'; provision it first." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "git not found, installing..."
    case "$OSTYPE" in
        darwin*)
            echo "Install Xcode Command Line Tools before running bootstrap." >&2
            exit 1
            ;;
        linux*)
            if command -v apt-get >/dev/null 2>&1; then
                apt_frontend=apt-get
                command -v nala >/dev/null 2>&1 && apt_frontend=nala
                command -v apt-fast >/dev/null 2>&1 && apt_frontend=apt-fast
                retry sudo -n env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
                    "$apt_frontend" update
                retry sudo -n env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
                    "$apt_frontend" install -y git
            elif command -v pacman >/dev/null 2>&1; then
                configure_bootstrap_pacman
                retry sudo -n pacman -Syu --noconfirm --needed git
            else
                echo "Install Git before running bootstrap." >&2
                exit 1
            fi
            ;;
        *)
            echo "Unsupported OS: $OSTYPE" >&2
            exit 1
            ;;
    esac
fi

mkdir -p "$(dirname "$TARGET")"
if [[ -d "$TARGET/.git" ]]; then
    echo "Already cloned at $TARGET — syncing to origin/main"
    [[ -z "$(git -C "$TARGET" status --porcelain)" ]] || {
        echo "ERROR: uncommitted changes in $TARGET" >&2
        exit 1
    }
    retry git -C "$TARGET" pull --ff-only
else
    echo "Cloning $REPO_URL -> $TARGET"
    retry git clone "$REPO_URL" "$TARGET"
fi

cd "$TARGET"
exec ./easy-install.sh
