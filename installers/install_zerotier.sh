#!/usr/bin/env bash
# shellcheck disable=SC2154

install_zerotier() {
    local script install_result=0
    command -v zerotier-cli >/dev/null 2>&1 && return 0
    if [[ "$os_id" == arch ]]; then
        linux_packages_install zerotier-one
        return
    fi
    [[ "$os_id" == ubuntu || "$os_id" == debian ]] || return 1

    # ZeroTier publishes a native package through its own APT repository.
    script=$(mktemp "${TMPDIR:-/tmp}/zerotier-install.XXXXXX")
    curl -fsSL https://install.zerotier.com -o "$script" || {
        rm -f "$script"
        return 1
    }
    sudo -n bash "$script" || install_result=$?
    rm -f "$script"
    ((install_result == 0)) && command -v zerotier-cli >/dev/null 2>&1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install zerotier" >&2
    exit 2
fi
