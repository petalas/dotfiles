#!/usr/bin/env bash
# Exercise model persistence through Pi's loader and startup model resolver.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if command -v node >/dev/null && command -v npm >/dev/null; then
    node --test --test-timeout=10000 "$root_dir/tests/test-pi-remember-model.mjs"
else
    printf 'Skipping Pi model persistence integration: Node.js and npm are required.\n'
fi
