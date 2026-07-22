#!/bin/sh
set -eu

retry() {
    attempt=1
    while ! "$@"; do
        if [ "$attempt" -ge 3 ]; then
            echo "Command failed after $attempt attempts: $*" >&2
            return 1
        fi
        echo "Command failed (attempt $attempt/3); retrying..." >&2
        sleep "$((attempt * 2))"
        attempt=$((attempt + 1))
    done
}

case "${DISTRO:-}" in
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        retry apt-get update
        retry apt-get install -y --no-install-recommends sudo
        rm -rf /var/lib/apt/lists/*
        ;;
    arch)
        retry pacman --disable-sandbox -Sy --noconfirm --needed sudo
        ;;
    *)
        echo "Unsupported integration-test distribution: ${DISTRO:-unset}" >&2
        exit 1
        ;;
esac

useradd --create-home --shell /bin/bash dotfiles
printf 'dotfiles ALL=(ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/dotfiles
chmod 0440 /etc/sudoers.d/dotfiles
