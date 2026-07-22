#!/usr/bin/env bash
set -euo pipefail

os_name="$(uname -s)"
arch_name="$(uname -m)"

if [[ "$os_name" != "Darwin" ]]; then
	echo "Expected macOS/Darwin runner, got: $os_name" >&2
	exit 1
fi

if [[ "$arch_name" != "arm64" ]]; then
	echo "Expected Apple Silicon arm64 runner, got: $arch_name" >&2
	exit 1
fi

"$(dirname "${BASH_SOURCE[0]}")/test-easy-install-noninteractive.sh"
"$(dirname "${BASH_SOURCE[0]}")/test-yazi-config.sh"

echo "macOS arm64 smoke tests passed."
