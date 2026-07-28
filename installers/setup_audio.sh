#!/usr/bin/env bash
# shellcheck disable=SC2154

setup_audio() {
    local -a packages=(
        pulseaudio libasound2 libasound2-plugins libasound2-doc alsa-utils
        alsa-oss alsamixergui apulse alsa-firmware-loaders
        pulseaudio-module-bluetooth
    )

    [[ "$os_id" == ubuntu || "$os_id" == debian ]] || return 1
    linux_packages_install_available "${packages[@]}"
    sudo -n alsactl init
    sudo -n systemctl restart bluetooth.service
    echo "${yellow}Attempting to power-cycle Bluetooth (timeout 10s)...${reset}"
    timeout 10 bash -c 'bluetoothctl power off && bluetoothctl power on'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this setup through: ./install audio" >&2
    exit 2
fi
