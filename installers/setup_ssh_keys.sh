#!/usr/bin/env bash

# Generate an ed25519 SSH key if missing and print the public key for
# adding to GitHub / Tailscale / remote authorized_keys. On macOS and
# Wayland systems also copies the pubkey to the clipboard for convenience.
# The key is created passphrase-less for scripted use — add a passphrase
# later with `ssh-keygen -p -f ~/.ssh/id_ed25519` if you prefer.
setup_ssh_keys() {
	local key="$HOME/.ssh/id_ed25519"

	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"

	if [[ -f "$key" ]]; then
		echo "SSH key already exists at $key"
		if [[ ! -f "$key.pub" ]]; then
			ssh-keygen -y -f "$key" >"$key.pub" || return 1
			chmod 644 "$key.pub"
			echo "Recreated missing public key: $key.pub"
		fi
	else
		local email
		email=$(git config --global user.email 2>/dev/null || true)
		if [[ -z "$email" ]]; then
			if [[ -n "${SSH_KEY_EMAIL:-}" ]]; then
				email="$SSH_KEY_EMAIL"
			elif [[ -t 0 ]]; then
				printf 'Enter email for SSH key comment: '
				read -r email
			else
				echo "Set SSH_KEY_EMAIL or configure git user.email before unattended key setup." >&2
				return 1
			fi
		fi
		echo "Generating $key..."
		ssh-keygen -t ed25519 -C "$email" -f "$key" -N "" || return 1
		chmod 600 "$key"
		chmod 644 "$key.pub"
	fi

	echo ""
	echo "Public key (add to GitHub, Tailscale, remote authorized_keys):"
	cat "$key.pub"

	if command -v pbcopy >/dev/null 2>&1; then
		if pbcopy <"$key.pub"; then
			echo ""
			echo "Copied to clipboard (pbcopy)."
		else
			echo "Warning: pbcopy could not access the clipboard." >&2
		fi
	elif [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
		if wl-copy <"$key.pub"; then
			echo ""
			echo "Copied to clipboard (wl-copy)."
		else
			echo "Warning: wl-copy could not access the clipboard." >&2
		fi
	elif [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
		if xclip -selection clipboard <"$key.pub"; then
			echo ""
			echo "Copied to clipboard (xclip)."
		else
			echo "Warning: xclip could not access the clipboard." >&2
		fi
	fi
}
