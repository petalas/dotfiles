#!/usr/bin/env bash
# Exercise the real extension through Pi's loader when Pi is installed.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if command -v node >/dev/null && command -v npm >/dev/null; then
    node --test "$root_dir/tests/test-pi-fast-mode.mjs"
else
    printf 'Skipping Pi fast-mode integration: Node.js and npm are required.\n'
fi
