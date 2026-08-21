#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../lib/platform.sh
source "$DOTFILES_ROOT/lib/platform.sh"
# shellcheck source=../lib/download.sh
source "$DOTFILES_ROOT/lib/download.sh"
# shellcheck source=../lib/packages.sh
source "$DOTFILES_ROOT/lib/packages.sh"
# shellcheck source=sdkman.sh disable=SC1091
source "$SCRIPT_DIR/sdkman.sh"

# The catalog engine overrides this hook to expose installer-owned operations
# in run progress. Direct installer calls retain the same behavior without
# depending on the engine.
if ! declare -F run_installer_operation >/dev/null 2>&1; then
    run_installer_operation() {
        shift 2
        "$@"
    }
fi

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
