#!/usr/bin/env bash

# Terminal colors, available to all sourced installers. Defined here instead
# of redeclared at the top of each installer. Installers run directly (i.e.
# not via source_installers.sh, brew-deps.sh, linux-deps.sh, or ./install)
# will have these undefined, and ${red} etc. will expand to empty strings —
# output still works, just monochrome. Installers that can be sourced by a
# `set -u` caller must use ${red:-}/${reset:-} when colors are optional.
red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)

# Detect current OS. Sets globals:
#   $os_id                 — "macos" on darwin, /etc/os-release ID on linux
#                            (normalized: archarm -> arch)
#   $os_id_raw             — original /etc/os-release ID (pre-normalization),
#                            needed for cases where archarm differs from arch
#                            (e.g. reflector is x86-only; use rankmirrors on ARM)
#   $os_version_codename   — /etc/os-release VERSION_CODENAME (may be empty)
# Safe to call repeatedly.
detect_os() {
	if [[ "$OSTYPE" == darwin* ]]; then
		os_id="macos"
		os_id_raw="macos"
		return 0
	fi
	if [[ -f /etc/os-release ]]; then
		os_id=$(grep -w ID /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
		os_version_codename=$(grep -w VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)
	fi
	os_id_raw="$os_id"
	[[ "$os_id" == "archarm" ]] && os_id="arch"
	return 0
}
detect_os

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
