#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
export NONINTERACTIVE=1 HOMEBREW_NO_ASK=1

# Source this so a fresh Homebrew shellenv is available to this process.
# shellcheck source=setup-brew.sh
source ./setup-brew.sh
command -v brew >/dev/null 2>&1 || {
    echo "Homebrew installation failed." >&2
    exit 1
}

for group in CAD GAMING MOBILE; do
    value="SKIP_$group"
    [[ -z "${!value:-}" ]] || export "HOMEBREW_SKIP_$group=1"
done

run_optional() {
    local label="$1"
    shift
    if ! "$@"; then
        echo "Warning: $label failed." >&2
    fi
}

# Reconcile the full Brewfile first, then isolate only missing entries if one
# broken package makes the batch fail.
# shellcheck source=lib/homebrew.sh
source lib/homebrew.sh
run_optional "Homebrew update" brew update
run_optional "Brewfile installation" \
    homebrew_bundle_install_resilient "$PWD/Brewfile"

# shellcheck source=installers/source_installers.sh
source installers/source_installers.sh

# Homebrew installs Ghostty itself; this also sets it as the default terminal.
run_optional "Ghostty configuration" install_ghostty

command -v npm >/dev/null 2>&1 && run_optional "global Node packages" install_node_deps
run_optional "Bun" install_bun
if command -v cargo >/dev/null 2>&1; then
    run_optional "Rust packages" install_rust_deps
    run_optional "Yazi" install_yazi
fi

# Homebrew itself is the required boundary; individual applications are best effort.
exit 0
