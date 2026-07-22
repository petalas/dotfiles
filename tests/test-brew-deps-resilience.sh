#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-brew-deps.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-brew-deps.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture_dir/bin" "$fixture_dir/installers" "$fixture_dir/home"
cp "$repo_dir/brew-deps.sh" "$fixture_dir/brew-deps.sh"
touch "$fixture_dir/Brewfile"

cat >"$fixture_dir/setup-brew.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "$BREW_TEST_SCENARIO" == "bootstrap_failure" ]]; then
	echo "Homebrew bootstrap failed" >&2
	exit 1
fi
EOF

cat >"$fixture_dir/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >>"$BREW_TEST_LOG"

if [[ "$1" == "list" && "${2:-}" == "--formula" && "${3:-}" == "--full-name" ]]; then
	printf '%s\n' installed-formula neovim
	exit 0
fi

if [[ "$1" == "list" && "${2:-}" == "--cask" && "${3:-}" == "--full-name" ]]; then
	printf '%s\n' installed-cask
	exit 0
fi

if [[ "$1" == "list" ]]; then
	exit 1
fi

if [[ "$1" == "tap" && "$#" == "1" && "$BREW_TEST_SCENARIO" == "bundle_failure" ]]; then
	printf '%s\n' installed-tap
	exit 0
fi

if [[ "$1" == "install" && "$BREW_TEST_SCENARIO" == "required_failure" && "$2" == "jq" ]]; then
	echo "Error: jq failed to install" >&2
	exit 1
fi

if [[ "$1" == "bundle" && "${2:-}" == "cleanup" ]]; then
	echo 'Run `brew bundle cleanup --force` to make these changes.'
	echo '==> Do you want to proceed with the cleanup? [y/n]'
	exit 1
fi

if [[ "$1" == "bundle" && "${2:-}" == --file=* && "$BREW_TEST_SCENARIO" == "bundle_failure" ]]; then
	cat >&2 <<'ERROR'
Error: Refusing to load formula wix-incubator/brew/applesimutils from untrusted tap wix-incubator/brew.
Run `brew trust --formula wix-incubator/brew/applesimutils` or `brew trust wix-incubator/brew` to trust it.
ERROR
	exit 1
fi

if [[ "$1" == "bundle" && "${2:-}" == "list" && "$BREW_TEST_SCENARIO" == "bundle_failure" ]]; then
	case "${3:-}" in
		--tap) printf '%s\n' installed-tap wix-incubator/brew ;;
		--formula) printf '%s\n' installed-formula neovim wix-incubator/brew/applesimutils later-formula ;;
		--cask) printf '%s\n' installed-cask later-cask ;;
	esac
fi

if [[ "$BREW_TEST_SCENARIO" == "bundle_failure" && "$*" == "tap installed-tap" ]]; then
	echo "Warning: installed-tap is already tapped." >&2
	exit 0
fi

if [[ "$BREW_TEST_SCENARIO" == "bundle_failure" && "$*" == "install installed-formula" ]]; then
	echo "Warning: installed-formula is already installed and up-to-date." >&2
	echo "To reinstall, run:" >&2
	echo "  brew reinstall installed-formula" >&2
	exit 0
fi

if [[ "$BREW_TEST_SCENARIO" == "bundle_failure" && "$*" == "install neovim" ]]; then
	echo "Error: neovim HEAD is already installed" >&2
	echo "To install stable first run: brew unlink neovim" >&2
	exit 1
fi

if [[ "$BREW_TEST_SCENARIO" == "bundle_failure" && "$*" == "install --cask installed-cask" ]]; then
	echo "Warning: installed-cask is already installed and up-to-date." >&2
	exit 0
fi

if [[ "$1" == "install" && "${2:-}" == "wix-incubator/brew/applesimutils" && "$BREW_TEST_SCENARIO" == "bundle_failure" ]]; then
	echo "Error: applesimutils still failed" >&2
	exit 1
fi
EOF

for command in npm sdk cargo; do
	cat >"$fixture_dir/bin/$command" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
done

cat >"$fixture_dir/installers/source_installers.sh" <<'EOF'
record_installer() {
	printf '%s\n' "$1" >>"$BREW_TEST_LOG"
}

install_neovim() { record_installer neovim; }
install_node() {
	record_installer node
	[[ "$BREW_TEST_SCENARIO" != "node_failure" ]]
}
install_node_deps() { record_installer node_deps; }
install_bun() { record_installer bun; }
install_sdkman() { record_installer sdkman; }
install_sdkman_deps() { record_installer sdkman_deps; }
install_rust() { record_installer rust; }
install_rust_deps() { record_installer rust_deps; }
install_yazi() { record_installer yazi; }
EOF

chmod +x "$fixture_dir/bin"/* "$fixture_dir/setup-brew.sh"

run_scenario() {
	local scenario="$1"
	local output_file="$fixture_dir/$scenario-output"
	export BREW_TEST_LOG="$fixture_dir/$scenario-log"
	: >"$BREW_TEST_LOG"

	if (
		cd "$fixture_dir"
		env \
			BREW_TEST_SCENARIO="$scenario" \
			HOME="$fixture_dir/home" \
			OSTYPE=darwin-test \
			PATH="$fixture_dir/bin:/usr/bin:/bin" \
			bash ./brew-deps.sh
	) >"$output_file" 2>&1; then
		return 0
	fi
	return 1
}

assert_logged() {
	local value="$1"
	grep -Fxq -- "$value" "$BREW_TEST_LOG" || {
		echo "Expected log entry: $value" >&2
		cat "$BREW_TEST_LOG" >&2
		exit 1
	}
}

assert_not_logged() {
	local value="$1"
	if grep -Fxq -- "$value" "$BREW_TEST_LOG"; then
		echo "Unexpected log entry: $value" >&2
		cat "$BREW_TEST_LOG" >&2
		exit 1
	fi
}

# A failed optional Brewfile entry must not block independent installers.
run_scenario bundle_failure || {
	cat "$fixture_dir/bundle_failure-output" >&2
	exit 1
}
grep -Fq 'Refusing to load formula wix-incubator/brew/applesimutils' \
	"$fixture_dir/bundle_failure-output"
assert_logged 'brew tap wix-incubator/brew'
assert_logged 'brew install later-formula'
assert_logged 'brew install --cask later-cask'
assert_logged 'brew tap'
assert_logged 'brew list --formula --full-name'
assert_logged 'brew list --cask --full-name'
assert_not_logged 'brew tap installed-tap'
assert_not_logged 'brew install installed-formula'
assert_not_logged 'brew install neovim'
assert_not_logged 'brew install --cask installed-cask'
if grep -Fq 'already installed and up-to-date' "$fixture_dir/bundle_failure-output"; then
	echo "Fallback retried packages that were already installed" >&2
	exit 1
fi
assert_not_logged 'brew bundle cleanup --file=./Brewfile'
if grep -Fq 'Do you want to proceed with the cleanup' "$fixture_dir/bundle_failure-output"; then
	echo "brew-deps emitted an interactive cleanup prompt" >&2
	exit 1
fi
grep -Fq 'Setup completed with 2 warning(s)' "$fixture_dir/bundle_failure-output"
for installer in neovim node node_deps bun sdkman sdkman_deps rust rust_deps yazi; do
	assert_logged "$installer"
done

# Homebrew and jq, which required dotfile linking consumes, are hard requirements.
if run_scenario bootstrap_failure; then
	echo "Expected Homebrew bootstrap failure to stop brew-deps" >&2
	exit 1
fi
assert_not_logged neovim

if run_scenario required_failure; then
	echo "Expected a required formula failure to stop brew-deps" >&2
	exit 1
fi
assert_not_logged neovim

# Dependent work is skipped after its prerequisite fails; unrelated work continues.
run_scenario node_failure || {
	cat "$fixture_dir/node_failure-output" >&2
	exit 1
}
assert_logged node
assert_not_logged node_deps
grep -Fq 'Skipping global Node packages because its prerequisite failed' \
	"$fixture_dir/node_failure-output"
for installer in bun sdkman sdkman_deps rust rust_deps yazi; do
	assert_logged "$installer"
done

echo "Homebrew dependency resilience tests passed."
