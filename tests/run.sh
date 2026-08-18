#!/usr/bin/env bash
# Run deterministic, platform-independent tests.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

tests=(
    tests/test-bootstrap-contract.sh
    tests/test-dependency-wrapper.sh
    tests/test-easy-install-noninteractive.sh
    tests/test-git-sync.sh
    tests/test-homebrew.sh
    tests/test-install-catalog.sh
    tests/test-install-plan.sh
    tests/test-install-plan-apply.sh
    tests/test-install-selector.sh
    tests/test-language-deps.sh
    tests/test-link-path.sh
    tests/test-link-dotfiles.sh
    tests/test-linux-packages.sh
    tests/test-nvim-github-auth.sh
    tests/test-nvim-sync.sh
    tests/test-script-contracts.sh
    tests/test-update-install-plan.sh
    tests/test-yazi.sh
    tests/test-zsh-startup.sh
)

failures=()
for test_file in "${tests[@]}"; do
    printf '\n==> %s\n' "$test_file"
    if ! "$test_file"; then
        failures+=("$test_file")
    fi
done

if ((${#failures[@]})); then
    printf '\nFailed tests: %s\n' "${failures[*]}" >&2
    exit 1
fi
printf '\nAll deterministic tests passed.\n'
