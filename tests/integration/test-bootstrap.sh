#!/usr/bin/env bash
set -euo pipefail

target="${DOTFILES_DIR:-$HOME/git/dotfiles}"
bootstrap_script="${BOOTSTRAP_SCRIPT:-/usr/local/bin/bootstrap-dotfiles}"
repo_url="${DOTFILES_REPO_URL:?DOTFILES_REPO_URL is required}"
preflight_url="${DOTFILES_PREFLIGHT_URL:?DOTFILES_PREFLIGHT_URL is required}"
state_manifest=/tmp/dotfiles-bootstrap-state

run_bootstrap() {
    local phase="$1"
    local log_file="/tmp/dotfiles-bootstrap-${phase}.log"
    local bootstrap_status

    set +e
    DOTFILES_DIR="$target" \
        DOTFILES_REPO_URL="$repo_url" \
        DOTFILES_PREFLIGHT_URL="$preflight_url" \
        "$bootstrap_script" 2>&1 | tee "$log_file"
    bootstrap_status=${PIPESTATUS[0]}
    set -e

    if ((bootstrap_status != 0)); then
        echo "bootstrap failed during $phase (status $bootstrap_status)" >&2
        return "$bootstrap_status"
    fi
    if grep -Eq 'Setup completed with [1-9][0-9]* warning\(s\)' "$log_file"; then
        echo "bootstrap completed with unexpected warnings during $phase" >&2
        return 1
    fi
}

command -v git >/dev/null 2>&1 && {
    echo "bootstrap fixture unexpectedly includes Git" >&2
    exit 1
}

run_bootstrap first
first_log=/tmp/dotfiles-bootstrap-first.log
grep -Fq 'git not found, installing...' "$first_log"
grep -Fq "Cloning $repo_url -> $target" "$first_log"
"$target/tests/integration/assert-install.sh"
"$target/tests/integration/state-manifest.sh" record "$state_manifest"

tmux new-session -d -s stale-config
tmux set-environment -gu TMUX_PLUGIN_MANAGER_PATH
run_bootstrap second
grep -Fq "Already cloned at $target — syncing to origin/main" \
    /tmp/dotfiles-bootstrap-second.log
EXPECT_STALE_TMUX_RELOAD=1 "$target/tests/integration/assert-install.sh"
"$target/tests/integration/state-manifest.sh" compare "$state_manifest"

printf '\nbootstrap dirty-worktree probe\n' >>"$target/README.md"
set +e
DOTFILES_DIR="$target" \
    DOTFILES_REPO_URL="$repo_url" \
    DOTFILES_PREFLIGHT_URL="$preflight_url" \
    "$bootstrap_script" >/tmp/dotfiles-bootstrap-dirty.log 2>&1
dirty_status=$?
set -e
git -C "$target" checkout -- README.md

if ((dirty_status == 0)); then
    echo "bootstrap accepted a dirty worktree" >&2
    exit 1
fi
grep -Fq "ERROR: uncommitted changes in $target" /tmp/dotfiles-bootstrap-dirty.log

echo "Bootstrap integration assertions passed."
