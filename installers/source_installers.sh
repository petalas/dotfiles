#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../lib/platform.sh
source "$DOTFILES_ROOT/lib/platform.sh"
# shellcheck source=../lib/download.sh
source "$DOTFILES_ROOT/lib/download.sh"
# shellcheck source=../lib/packages.sh
source "$DOTFILES_ROOT/lib/packages.sh"

for script in "$SCRIPT_DIR"/install_*.sh "$SCRIPT_DIR"/setup_*.sh; do
    # shellcheck disable=SC1090
    source "$script"
done

list_installers() {
    local category name previous=
    echo 'Available installers:'
    while IFS=$'\t' read -r category name; do
        [[ -n "$category$name" ]] || continue
        if [[ "$category" != "$previous" ]]; then
            printf '  %s:\n' "$category"
            previous=$category
        fi
        printf '    %s\n' "$name"
    done <"$DOTFILES_ROOT/catalog/installers.tsv"
}
