#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d /tmp/dotfiles-easy-install.XXXXXX)
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/bin" "$fixture_dir/home" "$fixture_dir/installers"
cp "$repo_dir/easy-install.sh" "$fixture_dir/easy-install.sh"

cat >"$fixture_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ "${TEST_SCENARIO:-}" != sudo_failure ]]
EOF
cat >"$fixture_dir/setup-deps.sh" <<'EOF'
#!/usr/bin/env bash
[[ "${NONINTERACTIVE:-}" == 1 ]]
[[ "${HOMEBREW_NO_ASK:-}" == 1 ]]
if IFS= read -r _; then
    echo "stdin was not closed" >&2
    exit 1
fi
printf 'dependencies\n' >>"$TEST_STEPS"
[[ "${TEST_SCENARIO:-}" != dependency_failure ]]
EOF
cat >"$fixture_dir/link-dotfiles.sh" <<'EOF'
#!/usr/bin/env bash
printf 'links\n' >>"$TEST_STEPS"
EOF
cat >"$fixture_dir/setup-tools.sh" <<'EOF'
#!/usr/bin/env bash
printf 'tools\n' >>"$TEST_STEPS"
[[ "${TEST_SCENARIO:-}" != tool_failure ]]
EOF
cat >"$fixture_dir/setup-fonts.sh" <<'EOF'
#!/usr/bin/env bash
printf 'fonts\n' >>"$TEST_STEPS"
[[ "${TEST_SCENARIO:-}" != font_failure ]]
EOF
cat >"$fixture_dir/installers/setup_zsh.sh" <<'EOF'
setup_zsh() { printf 'zsh\n' >>"$TEST_STEPS"; }
EOF
cat >"$fixture_dir/configure-zsh.sh" <<'EOF'
#!/usr/bin/env bash
printf 'plugins\n' >>"$TEST_STEPS"
EOF
chmod +x "$fixture_dir/bin/sudo" "$fixture_dir"/*.sh
mkdir -p "$fixture_dir/lib"
cp "$repo_dir/lib/platform.sh" "$fixture_dir/lib/platform.sh"

steps="$fixture_dir/steps"
run_install() {
    local scenario="$1"
    : >"$steps"
    env TEST_SCENARIO="$scenario" TEST_STEPS="$steps" \
        HOME="$fixture_dir/home" OSTYPE=darwin-test \
        PATH="$fixture_dir/bin:/usr/bin:/bin" \
        "${EASY_INSTALL_TEST_ENTRY_BASH:-$BASH}" "$fixture_dir/easy-install.sh" \
        >"$fixture_dir/$scenario.log" 2>&1
}

run_install success
[[ "$(cat "$steps")" == $'dependencies\nplugins\nlinks\ntools\nfonts\nzsh' ]]

if run_install font_failure; then
    echo "Expected an optional failure to produce a nonzero final status" >&2
    exit 1
fi
[[ "$(cat "$steps")" == $'dependencies\nplugins\nlinks\ntools\nfonts\nzsh' ]]
grep -Fq 'font setup failed; continuing' "$fixture_dir/font_failure.log"

if run_install dependency_failure; then
    echo "Expected dependency failure to stop setup" >&2
    exit 1
fi
[[ "$(cat "$steps")" == dependencies ]]

if run_install sudo_failure; then
    echo "Expected missing non-interactive sudo to stop setup" >&2
    exit 1
fi
[[ ! -s "$steps" ]]
grep -Fq "requires working 'sudo -n'" "$fixture_dir/sudo_failure.log"

echo "easy-install non-interactive contract tests passed."
