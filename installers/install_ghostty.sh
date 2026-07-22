#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh

_detect_os_for_ghostty() {
	if [[ "$OSTYPE" == darwin* ]]; then
		os_id="macos"
		return 0
	fi
	if [[ -f /etc/os-release ]]; then
		os_id=$(grep -w ID /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
		[[ "$os_id" == "archarm" ]] && os_id="arch"
		return 0
	fi
	os_id=""
}

set_ghostty_default_terminal() {
	[[ "${os_id:-}" == "arch" || "${os_id:-}" == "ubuntu" || "${os_id:-}" == "debian" ]] || return 0

	mkdir -p "$HOME/.config"
	for desktop_file in \
		/usr/share/applications/com.mitchellh.ghostty.desktop \
		/usr/local/share/applications/com.mitchellh.ghostty.desktop \
		/usr/share/applications/ghostty.desktop \
		/usr/local/share/applications/ghostty.desktop; do
		if [[ -f "$desktop_file" ]]; then
			basename "$desktop_file" >"$HOME/.config/xdg-terminals.list"
			return 0
		fi
	done

	# Ghostty's Linux app ID is com.mitchellh.ghostty; write the expected
	# desktop entry name even if the package manager installed it elsewhere.
	echo 'com.mitchellh.ghostty.desktop' >"$HOME/.config/xdg-terminals.list"
}

install_ghostty() {
	if [[ -z "${os_id:-}" ]]; then
		_detect_os_for_ghostty
	fi

	if command -v ghostty >/dev/null 2>&1; then
		echo "${green:-}ghostty${reset:-} is already installed."
		set_ghostty_default_terminal
		return 0
	fi
	if [[ "$os_id" == "macos" ]] && command -v brew >/dev/null 2>&1 && brew list --cask ghostty >/dev/null 2>&1; then
		echo "${green:-}ghostty${reset:-} is already installed."
		return 0
	fi

	if [[ "$os_id" == "macos" ]]; then
		echo "Installing ${yellow:-}ghostty${reset:-} ..."
		brew install --cask ghostty
	elif [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
		echo "Installing ${yellow:-}ghostty${reset:-} ..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)" || return 1
		set_ghostty_default_terminal
	elif [[ "$os_id" == "arch" ]]; then
		echo "Installing ${yellow:-}ghostty${reset:-} ..."
		paru -S --noconfirm --needed ghostty || return 1
		set_ghostty_default_terminal
	else
		echo "Unsupported OS: $os_id"
		return 1
	fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	install_ghostty
fi
