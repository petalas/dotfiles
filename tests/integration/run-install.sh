#!/usr/bin/env bash
set -euo pipefail

phase="${1:?usage: run-install.sh PHASE}"
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_dir"

if ! ./easy-install.sh; then
    echo "easy-install failed during $phase" >&2
    exit 1
fi

./tests/integration/assert-install.sh
