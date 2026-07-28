#!/usr/bin/env bash

red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)

os_id=""
os_id_raw=""
os_version_codename=""
if [[ $OSTYPE == darwin* ]]; then
    os_id=macos
elif [[ -r /etc/os-release ]]; then
    os_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    os_version_codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"' || true)
fi
os_id_raw="$os_id"
[[ "$os_id" != archarm ]] || os_id=arch

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../lib/packages.sh
source "$DOTFILES_ROOT/lib/packages.sh"

for script in "$SCRIPT_DIR"/install_*.sh "$SCRIPT_DIR"/setup_*.sh; do
    # shellcheck disable=SC1090
    source "$script"
done

list_installers() {
    local script
    echo "Available installers:"
    for script in "$SCRIPT_DIR"/install_*.sh "$SCRIPT_DIR"/setup_*.sh; do
        printf '  - %s\n' "$(basename "$script" .sh | sed -E 's/^(install|setup)_//')"
    done
}
