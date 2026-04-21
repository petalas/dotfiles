#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


setup_audio() {
    if [[ (! $OSTYPE == "linux"*) ]]; then
        return 1
    fi
    # splitting them up so that the script does not get stuck if any of them can't be located (eg when installing in a VM)
    # TODO: better solution https://superuser.com/a/1609471
    for i in pulseaudio libasound2 libasound2-plugins libasound2-doc alsa-utils alsa-oss alsamixergui apulse alsa-firmware-loaders pulseaudio-module-bluetooth -yq; do
        sudo apt install -yq $i
    done
    sudo alsactl init
    sudo systemctl restart bluetooth.service
    echo "${yellow}Attempting to power-cycle bluetooth (timeout 10s)...${reset}"
    timeout 10 bash -c 'bluetoothctl power off && bluetoothctl power on'
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_audio
fi 
