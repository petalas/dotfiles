#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-easy-install.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-easy-install.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture_dir/bin" "$fixture_dir/installers" "$fixture_dir/home"
cp "$repo_dir/easy-install.sh" "$fixture_dir/easy-install.sh"

cat >"$fixture_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$fixture_dir/setup-deps.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "${HOMEBREW_NO_ASK:-}" != "1" ]]; then
	cat <<'PROMPT'
==> Would upgrade 1 outdated package
bind 9.20.24 -> 9.20.26 (2.3MB)
==> Do you want to proceed with the upgrade? [y/n]
PROMPT
	exit 1
fi
[[ "${NONINTERACTIVE:-}" == "1" ]]
printf 'dependencies\n' >>"$EASY_INSTALL_STEPS"
[[ "${EASY_INSTALL_TEST_SCENARIO:-}" != "dependency_failure" ]]
EOF

cat >"$fixture_dir/setup-fonts.sh" <<'EOF'
#!/usr/bin/env bash
[[ "${HOMEBREW_NO_ASK:-}" == "1" ]]
[[ "${NONINTERACTIVE:-}" == "1" ]]
printf 'fonts\n' >>"$EASY_INSTALL_STEPS"
[[ "${EASY_INSTALL_TEST_SCENARIO:-}" != "font_failure" ]]
EOF

cat >"$fixture_dir/installers/setup_zsh.sh" <<'EOF'
setup_zsh() {
	[[ "${HOMEBREW_NO_ASK:-}" == "1" ]]
	[[ "${NONINTERACTIVE:-}" == "1" ]]
	printf 'zsh\n' >>"$EASY_INSTALL_STEPS"
}
EOF

for script in configure-zsh.sh link-dotfiles.sh; do
	cat >"$fixture_dir/$script" <<'EOF'
#!/usr/bin/env bash
[[ "${HOMEBREW_NO_ASK:-}" == "1" ]]
[[ "${NONINTERACTIVE:-}" == "1" ]]
printf '%s\n' "${0##*/}" >>"$EASY_INSTALL_STEPS"
EOF
done

chmod +x "$fixture_dir/bin/sudo" "$fixture_dir"/*.sh

export EASY_INSTALL_STEPS="$fixture_dir/steps"
run_easy_install() {
	local scenario="$1"
	local output_file="$fixture_dir/$scenario-output"
	: >"$EASY_INSTALL_STEPS"
	env \
		EASY_INSTALL_TEST_SCENARIO="$scenario" \
		HOME="$fixture_dir/home" \
		OSTYPE=darwin-test \
		PATH="$fixture_dir/bin:/usr/bin:/bin" \
		bash "$fixture_dir/easy-install.sh" </dev/null >"$output_file" 2>&1
}

run_easy_install success || {
	cat "$fixture_dir/success-output" >&2
	exit 1
}

expected_steps=$(cat <<'EOF'
dependencies
fonts
zsh
configure-zsh.sh
link-dotfiles.sh
EOF
)
actual_steps=$(cat "$EASY_INSTALL_STEPS")
[[ "$actual_steps" == "$expected_steps" ]] || {
	printf 'Unexpected easy-install steps:\n%s\n' "$actual_steps" >&2
	exit 1
}

if grep -Fq 'Do you want to proceed' "$fixture_dir/success-output"; then
	echo "easy-install emitted an interactive package-manager prompt" >&2
	exit 1
fi

# Optional setup failures should not block later independent stages.
run_easy_install font_failure || {
	cat "$fixture_dir/font_failure-output" >&2
	exit 1
}
actual_steps=$(cat "$EASY_INSTALL_STEPS")
[[ "$actual_steps" == "$expected_steps" ]] || {
	printf 'Unexpected steps after optional font failure:\n%s\n' "$actual_steps" >&2
	exit 1
}
grep -Fq 'Setup completed with 1 warning(s)' "$fixture_dir/font_failure-output"

# Dependency setup is a hard requirement for the remaining pipeline.
if run_easy_install dependency_failure; then
	echo "Expected dependency setup failure to stop easy-install" >&2
	exit 1
fi
actual_steps=$(cat "$EASY_INSTALL_STEPS")
[[ "$actual_steps" == "dependencies" ]] || {
	printf 'Unexpected steps after required dependency failure:\n%s\n' "$actual_steps" >&2
	exit 1
}

echo "easy-install macOS non-interactive environment test passed."
