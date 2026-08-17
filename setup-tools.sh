#!/usr/bin/env bash
# Restore repositories, plugins, caches, and other generated tool state after
# the tracked configuration has been linked.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$root_dir"
# shellcheck source=lib/git-sync.sh
source lib/git-sync.sh
# shellcheck source=lib/yazi.sh
source lib/yazi.sh

failures=()
run_best_effort() {
    local label="$1"
    shift
    printf '\n==> %s\n' "$label"
    if ! "$@"; then
        echo "Warning: $label failed; continuing." >&2
        failures+=("$label")
    fi
}

setup_nvim_repository() {
    clone_or_ff https://github.com/petalas/nvim.git "$HOME/.config/nvim" custom
}

setup_tmux_plugins() {
    clone_or_ff https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm"
    command -v tmux >/dev/null 2>&1 || return 0
    tmux start-server \; source-file "$HOME/.tmux.conf"
    _git_retry "Installing tmux plugins" "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

rebuild_bat_cache() {
    command -v bat >/dev/null 2>&1 || return 0
    bat cache --build
}

run_best_effort "Neovim configuration repository" setup_nvim_repository
run_best_effort "tmux plugins" setup_tmux_plugins
if command -v yazi >/dev/null 2>&1 || command -v ya >/dev/null 2>&1; then
    run_best_effort "Yazi packages" install_yazi_packages
fi
run_best_effort "bat cache" rebuild_bat_cache

if ((${#failures[@]})); then
    printf '\nGenerated tool setup failed: %s\n' "${failures[*]}" >&2
    exit 1
fi
