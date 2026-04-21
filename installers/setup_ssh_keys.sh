#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh

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
		echo "${green}SSH key already exists at $key${reset}"
	else
		local email
		email=$(git config --global user.email 2>/dev/null || true)
		if [[ -z "$email" ]]; then
			echo -n "Enter email for SSH key comment: "
			read -r email
		fi
		echo "Generating ${yellow}$key${reset}..."
		ssh-keygen -t ed25519 -C "$email" -f "$key" -N "" || return 1
		chmod 600 "$key"
		chmod 644 "$key.pub"
	fi

	echo ""
	echo "${yellow}Public key (add to GitHub, Tailscale, remote authorized_keys):${reset}"
	cat "$key.pub"

	if command -v pbcopy >/dev/null 2>&1; then
		pbcopy <"$key.pub"
		echo ""
		echo "${green}Copied to clipboard (pbcopy).${reset}"
	elif command -v wl-copy >/dev/null 2>&1; then
		wl-copy <"$key.pub"
		echo ""
		echo "${green}Copied to clipboard (wl-copy).${reset}"
	elif command -v xclip >/dev/null 2>&1; then
		xclip -selection clipboard <"$key.pub"
		echo ""
		echo "${green}Copied to clipboard (xclip).${reset}"
	fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	setup_ssh_keys
fi
