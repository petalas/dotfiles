#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_chrome() {
	if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
		echo "${green}chrome${reset} is already installed."
		return 0
	fi


	if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
		echo "Installing ${yellow}chrome${reset} ..."

		# Download the key and store it in a trusted keyring
		wget -q -O - https://dl.google.com/linux/linux_signing_key.pub |
			gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg >/dev/null

		# Create the source list
		echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" |
			sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null

		# Update apt and install
		sudo apt update
		sudo apt-get install -y google-chrome-stable
	elif [[ "$os_id" == "arch" ]]; then
		echo "Installing ${yellow}chrome${reset} ..."
		paru -S --noconfirm --needed google-chrome
	else
		echo "Unsupported OS: $os_id"
		return 1
	fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	install_chrome
fi
