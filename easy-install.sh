#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ $OSTYPE != darwin* && $OSTYPE != linux* ]]; then
    echo "Unsupported OS: $OSTYPE" >&2
    exit 1
fi

# Setup is intentionally unattended. Provision sudo before running it instead
# of letting individual installers stop for a password halfway through.
export NONINTERACTIVE=1 HOMEBREW_NO_ASK=1 DOTFILES_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a GIT_TERMINAL_PROMPT=0
exec </dev/null

if ((EUID != 0)) && ! sudo -n true 2>/dev/null; then
    echo "Unattended setup requires working 'sudo -n'." >&2
    exit 1
fi

run_optional() {
    local label="$1"
    shift
    if ! "$@"; then
        echo "Warning: $label failed; continuing." >&2
        optional_failed=1
    fi
}

optional_failed=0

printf '\n==> Installing dependencies\n'
./setup-deps.sh

printf '\n==> Linking dotfiles\n'
./link-dotfiles.sh

printf '\n==> Installing fonts\n'
run_optional "font setup" ./setup-fonts.sh

printf '\n==> Setting the login shell\n'
# shellcheck source=installers/setup_zsh.sh
source installers/setup_zsh.sh
run_optional "login shell setup" setup_zsh

printf '\n==> Configuring Zsh plugins\n'
run_optional "Zsh plugin setup" ./configure-zsh.sh

if ((optional_failed)); then
    echo "Setup finished with optional failures." >&2
    exit 1
fi

echo "Setup complete. Log out and back in if the login shell changed."
