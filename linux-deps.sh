#!/usr/bin/env bash
# Compatibility entry point; catalog data owns Linux package declarations.
set -euo pipefail
root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/platform.sh
source "$root_dir/lib/platform.sh"
case "$(dotfiles_os)" in
    ubuntu|debian|arch) ;;
    *) echo 'linux-deps.sh requires a supported Linux distribution.' >&2; exit 1 ;;
esac
exec "$root_dir/setup-deps.sh"
