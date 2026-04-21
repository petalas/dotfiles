#!/usr/bin/env bash
# Bootstrap a fresh machine: install git if missing, clone dotfiles, run setup.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh | bash
#
# Honours $DOTFILES_DIR for a custom target (defaults to ~/git/dotfiles).

set -e

TARGET="${DOTFILES_DIR:-$HOME/git/dotfiles}"
REPO_URL="https://github.com/petalas/dotfiles.git"

preflight() {
	# Network — we're about to clone and download a lot.
	if ! curl -fsS --max-time 5 --head https://github.com >/dev/null 2>&1; then
		echo "ERROR: cannot reach github.com — check network" >&2
		exit 1
	fi

	# TERM capability — tput needs a terminfo entry that defines 'setaf'.
	# vt220 / dumb / unset all fail. Try to upgrade silently; if none of the
	# common modern entries work either, continue monochrome.
	if ! tput setaf 1 >/dev/null 2>&1; then
		local original="${TERM:-unset}"
		local try
		for try in xterm-256color xterm-color xterm screen linux; do
			if TERM="$try" tput setaf 1 >/dev/null 2>&1; then
				export TERM="$try"
				echo "TERM upgraded from '$original' to '$try' for color support"
				break
			fi
		done
		if ! tput setaf 1 >/dev/null 2>&1; then
			echo "warning: no capable TERM found (tried xterm-256color, xterm, screen, linux); setup will continue monochrome"
		fi
	fi

	# $HOME writable — catches broken mounts / weird chroot setups early.
	if ! touch "$HOME/.dotfiles-bootstrap-probe" 2>/dev/null; then
		echo "ERROR: \$HOME=$HOME is not writable" >&2
		exit 1
	fi
	rm -f "$HOME/.dotfiles-bootstrap-probe"
}

preflight

ensure_git() {
	command -v git >/dev/null 2>&1 && return

	echo "git not found, installing..."
	case "$OSTYPE" in
		darwin*)
			# macOS: xcode-select pops a GUI prompt; user must click Install.
			# We poll until git is available.
			xcode-select --install 2>/dev/null || true
			echo "Waiting for Xcode Command Line Tools install (accept the GUI prompt)..."
			until command -v git >/dev/null 2>&1; do
				sleep 5
			done
			;;
		linux*)
			if command -v apt >/dev/null 2>&1; then
				sudo apt update
				sudo apt install -y git
			elif command -v pacman >/dev/null 2>&1; then
				sudo pacman -Sy --noconfirm git
			elif command -v dnf >/dev/null 2>&1; then
				sudo dnf install -y git
			else
				echo "no known package manager — install git manually and re-run" >&2
				exit 1
			fi
			;;
		*)
			echo "Unsupported OS: $OSTYPE" >&2
			exit 1
			;;
	esac
}

ensure_git

mkdir -p "$(dirname "$TARGET")"
if [[ -d "$TARGET/.git" ]]; then
	# Refuse if there are uncommitted changes — bootstrap is a sync tool, not
	# a backup tool. Users with in-progress edits need to handle those first.
	if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
		echo "ERROR: uncommitted changes in $TARGET — commit/stash them or delete the dir" >&2
		exit 1
	fi

	echo "Already cloned at $TARGET — syncing to origin/main"
	git -C "$TARGET" fetch origin --quiet
	git -C "$TARGET" checkout main >/dev/null 2>&1 || true

	# Try fast-forward; on divergence (typically a force-push of rewritten
	# history) hard-reset instead. The local clone is treated as a cache —
	# no assumption that local commits are preserved.
	if ! git -C "$TARGET" merge --ff-only origin/main >/dev/null 2>&1; then
		echo "  local main diverged from origin (likely a force-push); resetting --hard"
		git -C "$TARGET" reset --hard origin/main
	fi
else
	echo "Cloning $REPO_URL -> $TARGET"
	git clone "$REPO_URL" "$TARGET"
fi

cd "$TARGET"
./easy-install.sh
