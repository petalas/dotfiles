#!/usr/bin/env bash

install_lazydocker() {
    if command -v lazydocker >/dev/null 2>&1; then
        return 0
    fi

    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_lazydocker
fi 