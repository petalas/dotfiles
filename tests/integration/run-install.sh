#!/usr/bin/env bash
set -euo pipefail

phase="${1:?usage: run-install.sh PHASE}"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
log_file="/tmp/dotfiles-${phase}.log"

cd "$repo_dir"
set +e
./easy-install.sh 2>&1 | tee "$log_file"
install_status=${PIPESTATUS[0]}
set -e

if ((install_status != 0)); then
    echo "easy-install failed during $phase (status $install_status)" >&2
    exit "$install_status"
fi

if grep -Eq 'Setup completed with [1-9][0-9]* warning\(s\)' "$log_file"; then
    echo "easy-install completed with unexpected warnings during $phase" >&2
    exit 1
fi

./tests/integration/assert-install.sh
