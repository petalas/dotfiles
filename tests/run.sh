#!/usr/bin/env bash
# Run deterministic, platform-independent tests.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

tests=(
    tests/test-ai-skills.sh
    tests/test-bootstrap-contract.sh
    tests/test-dependency-wrapper.sh
    tests/test-easy-install-noninteractive.sh
    tests/test-git-sync.sh
    tests/test-homebrew.sh
    tests/test-install-catalog.sh
    tests/test-install-observation.sh
    tests/test-install-plan.sh
    tests/test-install-plan-apply.sh
    tests/test-install-progress.sh
    tests/test-install-removal.sh
    tests/test-install-selector.sh
    tests/test-install-tui-bootstrap.sh
    tests/test-install-tui.sh
    tests/test-install-tui-terminal.sh
    tests/test-tui-release-manifest.sh
    tests/test-language-deps.sh
    tests/test-link-path.sh
    tests/test-link-dotfiles.sh
    tests/test-linux-packages.sh
    tests/test-managed-toolchains.sh
    tests/test-macos-terminal-profile.sh
    tests/test-neovim-install.sh
    tests/test-nvim-github-auth.sh
    tests/test-nvim-sync.sh
    tests/test-omp-install.sh
    tests/test-script-contracts.sh
    tests/test-seashells-palette.sh
    tests/test-setup-tools.sh
    tests/test-update-install-plan.sh
    tests/test-yazi.sh
    tests/test-zed-install.sh
    tests/test-zsh-startup.sh
)

# Tests are `set -e` scripts full of bare assertions such as `grep -q`, so a
# failure would otherwise exit silently. Source each test inside a shell whose
# ERR trap names the file, line, and command that failed.
run_test() {
    bash -c 'set -o errtrace; trap '"'"'echo "assertion failed at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2'"'"' ERR; . "$0"' "$1"
}

failures=()
for test_file in "${tests[@]}"; do
    printf '\n==> %s\n' "$test_file"
    if ! run_test "$test_file"; then
        failures+=("$test_file")
    fi
done

if ((${#failures[@]})); then
    printf '\nFailed tests: %s\n' "${failures[*]}" >&2
    exit 1
fi
printf '\nAll deterministic tests passed.\n'
