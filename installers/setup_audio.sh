#!/usr/bin/env bash

setup_audio() {
    local os
    local -a packages=(alsa-utils bluez)

    os=$(dotfiles_os) || return 1
    [[ "$os" == ubuntu || "$os" == debian ]] || {
        echo "Audio setup is supported only on Debian and Ubuntu." >&2
        return 1
    }

    if command -v pipewire >/dev/null 2>&1; then
        packages+=(pipewire pipewire-audio wireplumber)
    else
        packages+=(pulseaudio pulseaudio-module-bluetooth)
    fi
    linux_packages_install_available "${packages[@]}" || return 1

    if command -v alsactl >/dev/null 2>&1; then
        run_as_root alsactl init || return 1
    fi
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
        run_as_root systemctl restart bluetooth.service || return 1
    fi
    if command -v bluetoothctl >/dev/null 2>&1; then
        echo "Power-cycling Bluetooth (timeout 10s)..."
        timeout 10 bash -c 'bluetoothctl power off && bluetoothctl power on'
    fi
}
