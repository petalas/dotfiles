#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$root_dir"
# shellcheck source=lib/platform.sh
source lib/platform.sh

# Establish a valid locale before package managers and downstream installers.
./install locale

case "$(dotfiles_os)" in
    macos) ./brew-deps.sh ;;
    ubuntu|debian|arch) ./linux-deps.sh ;;
    *)
        echo "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac
