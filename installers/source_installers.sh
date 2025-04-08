#!/usr/bin/env bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source all installer scripts
for installer in "$SCRIPT_DIR"/install_*.sh; do
    if [ -f "$installer" ]; then
        echo "Loading installer: $(basename "$installer")"
        source "$installer"
    fi
done

# Source setup scripts
for setup in "$SCRIPT_DIR"/setup_*.sh; do
    if [ -f "$setup" ]; then
        echo "Loading setup: $(basename "$setup")"
        source "$setup"
    fi
done

# Function to list all available installers
list_installers() {
    echo "Available installers:"
    for installer in "$SCRIPT_DIR"/install_*.sh; do
        if [ -f "$installer" ]; then
            echo "  - $(basename "$installer" .sh)"
        fi
    done
    echo
    echo "Available setup scripts:"
    for setup in "$SCRIPT_DIR"/setup_*.sh; do
        if [ -f "$setup" ]; then
            echo "  - $(basename "$setup" .sh)"
        fi
    done
} 