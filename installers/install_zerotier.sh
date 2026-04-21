#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_zerotier() {
    if [ ! -f /usr/sbin/zerotier-one ]; then
        echo "Installing ${yellow}zerotier${reset}."
        curl -s https://install.zerotier.com | sudo bash || return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_zerotier
fi 
