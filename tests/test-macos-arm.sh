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

if ! brew list --versions bash >/dev/null 2>&1; then
	brew install bash
fi

system_bash_major=$(
	/bin/bash --noprofile --norc -c 'printf "%s" "${BASH_VERSINFO[0]}"'
)
EASY_INSTALL_TEST_ENTRY_BASH=/bin/bash \
	EASY_INSTALL_EXPECT_BOOTSTRAP_BASH_MAJOR="$system_bash_major" \
	/bin/bash "$(dirname "${BASH_SOURCE[0]}")/test-easy-install-noninteractive.sh"

echo "macOS arm64 smoke tests passed."
