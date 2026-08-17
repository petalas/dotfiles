#!/usr/bin/env bash

install_lazydocker() {
    local os
    command -v lazydocker >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1
    if [[ "$os" == arch ]]; then
        linux_packages_install lazydocker
    else
        run_downloaded_script bash \
            https://raw.githubusercontent.com/jesseduffield/lazydocker/7e7aadc2071d58031bf2daafca1fbd4093efc23f/scripts/install_update_linux.sh
    fi
}
