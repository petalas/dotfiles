#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
export NONINTERACTIVE=1 HOMEBREW_NO_ASK=1

# shellcheck source=lib/download.sh
source lib/download.sh
# Source the function so Homebrew's shell environment remains in this process.
# shellcheck source=setup-brew.sh
source ./setup-brew.sh
setup_homebrew
command -v brew >/dev/null 2>&1 || {
    echo "Homebrew installation failed." >&2
    exit 1
}

for group in CAD GAMING MOBILE; do
    value="SKIP_$group"
    [[ "${!value:-0}" != 1 ]] || export "HOMEBREW_SKIP_$group=1"
done

run_best_effort() {
    local label="$1"
    shift
    if ! "$@"; then
        echo "Warning: $label failed; continuing." >&2
    fi
    return 0
}

# Reconcile the full Brewfile first, then isolate only missing entries if one
# broken package makes the batch fail.
# shellcheck source=lib/homebrew.sh
source lib/homebrew.sh
run_best_effort "Homebrew update" brew update
run_best_effort "Brewfile installation" \
    homebrew_bundle_install_resilient "$PWD/Brewfile"

# shellcheck source=installers/source_installers.sh
source installers/source_installers.sh

# Homebrew installs Ghostty itself; the installer also applies Linux-only configuration.
run_best_effort "Ghostty configuration" install_ghostty

if command -v npm >/dev/null 2>&1; then
    run_best_effort "global Node packages" install_node_deps
fi
run_best_effort "Bun" install_bun
if command -v cargo >/dev/null 2>&1; then
    run_best_effort "Rust packages" install_rust_deps
    run_best_effort "Yazi" install_yazi
fi

# Homebrew itself is the required boundary; individual applications are best effort.
exit 0
