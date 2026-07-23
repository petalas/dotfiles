#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-easy-install.XXXXXX)
test_entry_bash="${EASY_INSTALL_TEST_ENTRY_BASH:-$BASH}"
test_modern_bash="$BASH"

if [[ ! -x "$test_entry_bash" ]]; then
	echo "Test entry Bash is not executable: $test_entry_bash" >&2
	exit 1
fi

if ! "$test_modern_bash" --noprofile --norc -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
	for candidate in \
		/opt/homebrew/opt/bash/bin/bash \
		/opt/homebrew/bin/bash \
		/usr/local/opt/bash/bin/bash \
		/usr/local/bin/bash; do
		if [[ -x "$candidate" ]] &&
			"$candidate" --noprofile --norc -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
			test_modern_bash="$candidate"
			break
		fi
	done
fi

if ! "$test_modern_bash" --noprofile --norc -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
	echo "A Bash 4+ binary is required for the easy-install bootstrap test" >&2
	exit 1
fi

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-easy-install.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

mkdir -p \
	"$fixture_dir/bin" \
	"$fixture_dir/home" \
	"$fixture_dir/homebrew/bin" \
	"$fixture_dir/incompatible-bash/bin" \
	"$fixture_dir/installers"
cp "$repo_dir/easy-install.sh" "$fixture_dir/easy-install.sh"
ln -s "$test_modern_bash" "$fixture_dir/homebrew/bin/bash"
cat >"$fixture_dir/incompatible-bash/bin/bash" <<'EOF'
#!/bin/sh
exit 1
EOF

cat >"$fixture_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$fixture_dir/setup-brew.sh" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${EASY_INSTALL_EXPECT_BOOTSTRAP_BASH_MAJOR:-}" ]]; then
	[[ "${BASH_VERSINFO[0]}" == "$EASY_INSTALL_EXPECT_BOOTSTRAP_BASH_MAJOR" ]]
fi
printf 'homebrew\n' >>"$EASY_INSTALL_STEPS"
EOF

cat >"$fixture_dir/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >>"$EASY_INSTALL_STEPS"
case "$*" in
	"list --versions bash")
		[[ "${EASY_INSTALL_TEST_SCENARIO:-}" != "bash_missing" ]]
		exit
		;;
	"update" | "upgrade bash" | "install bash") exit 0 ;;
	"--prefix bash")
		if [[ "${EASY_INSTALL_TEST_SCENARIO:-}" == "bash_incompatible" ]]; then
			printf '%s\n' "$EASY_INSTALL_INCOMPATIBLE_BASH_PREFIX"
		else
			printf '%s\n' "$EASY_INSTALL_HOMEBREW_PREFIX"
		fi
		exit 0
		;;
esac
exit 1
EOF

cat >"$fixture_dir/setup-deps.sh" <<'EOF'
#!/usr/bin/env bash
((BASH_VERSINFO[0] >= 4))
[[ "$(command -v bash)" == "$EASY_INSTALL_HOMEBREW_PREFIX/bin/bash" ]]
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

chmod +x \
	"$fixture_dir/bin"/* \
	"$fixture_dir/incompatible-bash/bin/bash" \
	"$fixture_dir"/*.sh

export EASY_INSTALL_STEPS="$fixture_dir/steps"
export EASY_INSTALL_HOMEBREW_PREFIX="$fixture_dir/homebrew"
export EASY_INSTALL_INCOMPATIBLE_BASH_PREFIX="$fixture_dir/incompatible-bash"
run_easy_install() {
	local scenario="$1"
	local output_file="$fixture_dir/$scenario-output"
	: >"$EASY_INSTALL_STEPS"
	env \
		EASY_INSTALL_TEST_SCENARIO="$scenario" \
		HOME="$fixture_dir/home" \
		OSTYPE=darwin-test \
		PATH="$fixture_dir/bin:/usr/bin:/bin" \
		"$test_entry_bash" "$fixture_dir/easy-install.sh" </dev/null >"$output_file" 2>&1
}

run_easy_install success || {
	cat "$fixture_dir/success-output" >&2
	exit 1
}

expected_steps=$(cat <<'EOF'
homebrew
brew update
brew list --versions bash
brew upgrade bash
brew --prefix bash
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
grep -Fq 'Restarting easy-install with' "$fixture_dir/success-output"

if grep -Fq 'Do you want to proceed' "$fixture_dir/success-output"; then
	echo "easy-install emitted an interactive package-manager prompt" >&2
	exit 1
fi

# A fresh machine without Homebrew Bash must install it before re-exec.
run_easy_install bash_missing || {
	cat "$fixture_dir/bash_missing-output" >&2
	exit 1
}
expected_missing_bash_steps=$(cat <<'EOF'
homebrew
brew update
brew list --versions bash
brew install bash
brew --prefix bash
dependencies
fonts
zsh
configure-zsh.sh
link-dotfiles.sh
EOF
)
actual_steps=$(cat "$EASY_INSTALL_STEPS")
[[ "$actual_steps" == "$expected_missing_bash_steps" ]] || {
	printf 'Unexpected fresh Bash bootstrap steps:\n%s\n' "$actual_steps" >&2
	exit 1
}

# Never enter general dependency setup if Homebrew resolves to an
# incompatible shell, even if the package-manager commands succeeded.
if run_easy_install bash_incompatible; then
	echo "Expected incompatible Homebrew Bash to stop easy-install" >&2
	exit 1
fi
grep -Fq 'Homebrew Bash is unavailable or older than Bash 4' \
	"$fixture_dir/bash_incompatible-output"
if grep -Fxq 'dependencies' "$EASY_INSTALL_STEPS"; then
	echo "Dependency setup ran under an incompatible Bash" >&2
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
expected_dependency_failure_steps=$(cat <<'EOF'
homebrew
brew update
brew list --versions bash
brew upgrade bash
brew --prefix bash
dependencies
EOF
)
[[ "$actual_steps" == "$expected_dependency_failure_steps" ]] || {
	printf 'Unexpected steps after required dependency failure:\n%s\n' "$actual_steps" >&2
	exit 1
}

echo "easy-install macOS non-interactive environment test passed."
