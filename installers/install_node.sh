#!/usr/bin/env bash

install_node() {
    local nvm_version=v0.40.6
    local nvm_installer="https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh"

    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    echo "Installing/updating nvm $nvm_version..."
    PROFILE=/dev/null run_downloaded_script bash "$nvm_installer" || return 1

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        echo "nvm did not install its loader at $NVM_DIR/nvm.sh" >&2
        return 1
    fi

    # nvm is a shell function, so it must be loaded into this process before
    # the catalog's npm actions run.
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    nvm install node --latest-npm || return 1
    nvm alias default node || return 1
    nvm use node || return 1
    hash -r 2>/dev/null || true

    case "$(command -v node 2>/dev/null || true)" in
        "$NVM_DIR"/versions/node/*/bin/node) ;;
        *)
            echo "The nvm-managed Node executable is not active" >&2
            return 1
            ;;
    esac
    command -v npm >/dev/null 2>&1 || {
        echo "npm is missing from the nvm-managed Node installation" >&2
        return 1
    }
}
