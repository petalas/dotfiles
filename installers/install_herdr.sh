#!/usr/bin/env bash

install_herdr() {
    if ! command -v herdr >/dev/null 2>&1; then
        echo "Installing herdr..."
        run_downloaded_script sh https://herdr.dev/install.sh || return 1
    fi
}
