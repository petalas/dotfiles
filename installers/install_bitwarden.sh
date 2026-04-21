#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_bitwarden() {
    if command -v bitwarden >/dev/null 2>&1; then
        echo "${green}bitwarden${reset} is already installed."
        return 0
    fi


    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        echo "Installing ${yellow}bitwarden${reset} ..."
        wget -q 'https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb' -O /tmp/bitwarden_amd64.deb
        sudo dpkg -i /tmp/bitwarden_amd64.deb
        sudo rm -f /tmp/bitwarden_amd64.deb
    elif [[ "$os_id" == "arch" ]]; then
        echo "Installing ${yellow}bitwarden${reset} ..."
        paru -S --noconfirm --needed bitwarden
    else
        echo "Unsupported OS: $os_id"
        return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_bitwarden
fi 
