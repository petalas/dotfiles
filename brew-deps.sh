#!/usr/bin/env bash
# Compatibility entry point; catalog data owns Homebrew declarations.
set -euo pipefail
root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/platform.sh
source "$root_dir/lib/platform.sh"
[[ $(dotfiles_os) == macos ]] || { echo 'brew-deps.sh requires macOS.' >&2; exit 1; }
exec "$root_dir/setup-deps.sh"
