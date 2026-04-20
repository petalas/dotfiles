#!/usr/bin/env bash

# Terminal colors, available to all sourced installers. Defined here instead
# of redeclared at the top of each installer. Installers run directly (i.e.
# not via source_installers.sh, brew-deps.sh, linux-deps.sh, or ./install)
# will have these undefined, and ${red} etc. will expand to empty strings —
# output still works, just monochrome.
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

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