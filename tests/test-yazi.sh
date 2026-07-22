#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-yazi.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-yazi.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture_dir/bin"
export YAZI_TEST_STATE="$fixture_dir/state"
export YAZI_TEST_SCENARIO="$fixture_dir/scenario"
export YAZI_TEST_LOG="$fixture_dir/commands"
export YAZI_CONFIG_HOME="$fixture_dir/yazi-config"
mkdir -p "$YAZI_CONFIG_HOME"
touch "$YAZI_CONFIG_HOME/package.toml"

cat >"$fixture_dir/bin/ya" <<'EOF'
#!/usr/bin/env bash
state=$(cat "$YAZI_TEST_STATE")

if [[ "${1:-}" == "--version" ]]; then
	case "$state" in
		legacy) echo "Ya 25.4.8 (test)" ;;
		mismatch|modern) echo "Ya 26.5.9 (test)" ;;
		*) exit 1 ;;
	esac
	exit 0
fi

if [[ "${1:-}" == "pkg" && "${2:-}" == "--help" ]]; then
	[[ "$state" == "modern" || "$state" == "mismatch" ]]
	exit
fi

if [[ "${1:-}" == "pkg" && "${2:-}" == "install" ]]; then
	printf 'ya:%s\n' "$*" >>"$YAZI_TEST_LOG"
	[[ "$state" == "modern" ]]
	exit
fi

exit 2
EOF

cat >"$fixture_dir/bin/yazi" <<'EOF'
#!/usr/bin/env bash
state=$(cat "$YAZI_TEST_STATE")

if [[ "${1:-}" == "--version" ]]; then
	case "$state" in
		legacy|mismatch) echo "Yazi 25.4.8 (test)" ;;
		modern) echo "Yazi 26.5.9 (test)" ;;
		*) exit 1 ;;
	esac
	exit 0
fi

exit 2
EOF

cat >"$fixture_dir/bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo:%s\n' "$*" >>"$YAZI_TEST_LOG"
scenario=$(cat "$YAZI_TEST_SCENARIO")

if [[ "$*" == "install --locked yazi-build" ]]; then
	[[ "$scenario" == "upgrade" ]] && echo modern >"$YAZI_TEST_STATE"
	exit 0
fi

if [[ "$*" == "install --force --locked yazi-build" ]]; then
	[[ "$scenario" == "repair" ]] && echo modern >"$YAZI_TEST_STATE"
	exit 0
fi

exit 2
EOF

chmod +x "$fixture_dir/bin/ya" "$fixture_dir/bin/yazi" "$fixture_dir/bin/cargo"
export PATH="$fixture_dir/bin:$PATH"

# shellcheck source=installers/install_yazi.sh disable=SC1091
source "$repo_dir/installers/install_yazi.sh"

assert_log_line() {
	local expected="$1"
	grep -Fqx "$expected" "$YAZI_TEST_LOG" || {
		echo "Expected command log to contain: $expected" >&2
		exit 1
	}
}

assert_no_log_line() {
	local unexpected="$1"
	if grep -Fqx "$unexpected" "$YAZI_TEST_LOG"; then
		echo "Expected command log not to contain: $unexpected" >&2
		exit 1
	fi
}

run_install_case() {
	local state="$1" scenario="$2"
	printf '%s\n' "$state" >"$YAZI_TEST_STATE"
	printf '%s\n' "$scenario" >"$YAZI_TEST_SCENARIO"
	: >"$YAZI_TEST_LOG"
	install_yazi >/dev/null
}

# An old but internally consistent Yazi is upgraded through the normal latest
# release check without forcing a rebuild first.
run_install_case legacy upgrade
assert_log_line 'cargo:install --locked yazi-build'
assert_no_log_line 'cargo:install --force --locked yazi-build'
yazi_is_compatible

# If Cargo considers yazi-build current but ya/yazi are stale or mismatched,
# force rebuilding the meta-package to repair both binaries as a pair.
run_install_case mismatch repair
assert_log_line 'cargo:install --locked yazi-build'
assert_log_line 'cargo:install --force --locked yazi-build'
yazi_is_compatible

# A current installation still checks for a newer release, but does not force
# recompilation when Cargo reports no update and the compatibility checks pass.
run_install_case modern current
assert_log_line 'cargo:install --locked yazi-build'
assert_no_log_line 'cargo:install --force --locked yazi-build'

# A successful Cargo exit is insufficient: yazi-build's build script can leave
# incompatible child binaries behind, so the installer must verify its output.
printf 'legacy\n' >"$YAZI_TEST_STATE"
printf 'broken\n' >"$YAZI_TEST_SCENARIO"
: >"$YAZI_TEST_LOG"
if install_yazi >/dev/null 2>&1; then
	echo "Expected install_yazi to reject incompatible binaries" >&2
	exit 1
fi
assert_log_line 'cargo:install --force --locked yazi-build'

# package.toml is canonical: restore its locked dependencies in one operation
# instead of re-adding and potentially rewriting each dependency.
printf 'modern\n' >"$YAZI_TEST_STATE"
: >"$YAZI_TEST_LOG"
install_yazi_packages
assert_log_line 'ya:pkg install'
if grep -Fq 'pkg add' "$YAZI_TEST_LOG"; then
	echo "Yazi packages must be restored from package.toml, not re-added" >&2
	exit 1
fi

echo "Yazi installer tests passed."
