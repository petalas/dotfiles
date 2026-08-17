#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$root_dir"
# shellcheck source=lib/platform.sh
source lib/platform.sh

if ! os=$(dotfiles_os); then
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
fi
if [[ "$os" == macos ]] && ((EUID == 0)); then
    echo "Run macOS setup as the target user, not root; Homebrew refuses root installs." >&2
    exit 1
fi

# Setup is intentionally unattended. Provision sudo before running it instead
# of allowing an installer to stop for a password halfway through.
export NONINTERACTIVE=1 HOMEBREW_NO_ASK=1 DOTFILES_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a GIT_TERMINAL_PROMPT=0
exec </dev/null
require_noninteractive_root

for command_name in curl git; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "Required command is missing before setup: $command_name" >&2
        exit 1
    }
done

failures=()
run_best_effort() {
    local label="$1"
    shift
    if ! "$@"; then
        echo "Warning: $label failed; continuing." >&2
        failures+=("$label")
    fi
}

printf '\n==> Installing dependencies for %s\n' "$os"
./setup-deps.sh

command -v jq >/dev/null 2>&1 || {
    echo "Required command is missing after dependency setup: jq" >&2
    exit 1
}

printf '\n==> Configuring Zsh plugins\n'
./configure-zsh.sh

printf '\n==> Linking dotfiles\n'
./link-dotfiles.sh

printf '\n==> Restoring generated tool state\n'
run_best_effort "tool state setup" ./setup-tools.sh

printf '\n==> Installing fonts\n'
run_best_effort "font setup" ./setup-fonts.sh

printf '\n==> Setting the login shell\n'
# shellcheck source=installers/setup_zsh.sh
source installers/setup_zsh.sh
run_best_effort "login shell setup" setup_zsh

if ((${#failures[@]})); then
    printf 'Setup finished with failures: %s\n' "${failures[*]}" >&2
    exit 1
fi

echo "Setup complete. Log out and back in if the login shell changed."
