#!/usr/bin/env bash

install_lazydocker() {
    command -v lazydocker >/dev/null 2>&1 && return 0
    if [[ "${os_id:-}" == arch ]]; then
        linux_packages_install lazydocker
    else
        curl -fsSL \
            https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh |
            bash
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_lazydocker
fi 