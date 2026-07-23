#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-language-deps.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-language-deps.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture_dir/bin"
export LANGUAGE_DEPS_LOG="$fixture_dir/commands"
export PATH="$fixture_dir/bin:/usr/bin:/bin"

cat >"$fixture_dir/bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
if IFS= read -r input; then
	printf 'npm consumed stdin: %s\n' "$input" >>"$LANGUAGE_DEPS_LOG"
fi
[[ "$*" != *typescript* ]]
EOF

cat >"$fixture_dir/bin/sdk" <<'EOF'
#!/usr/bin/env bash
printf 'sdk %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
if IFS= read -r input; then
	printf 'sdk consumed stdin: %s\n' "$input" >>"$LANGUAGE_DEPS_LOG"
fi
[[ "$*" != *kotlin* ]]
EOF

cat >"$fixture_dir/bin/rustup" <<'EOF'
#!/usr/bin/env bash
printf 'rustup %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
exit 1
EOF

cat >"$fixture_dir/bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
[[ "$*" != *ripgrep* ]]
EOF

chmod +x "$fixture_dir/bin"/*

yellow=''
reset=''
# shellcheck source=../installers/install_node_deps.sh
source "$repo_dir/installers/install_node_deps.sh"
# shellcheck source=../installers/install_sdkman_deps.sh
source "$repo_dir/installers/install_sdkman_deps.sh"
# shellcheck source=../installers/install_rust_deps.sh
source "$repo_dir/installers/install_rust_deps.sh"

assert_failed_after_attempting() {
	local label="$1"
	local final_command="$2"
	shift 2
	: >"$LANGUAGE_DEPS_LOG"
	if "$@"; then
		echo "Expected $label to report its package failure" >&2
		exit 1
	fi
	grep -Fq "$final_command" "$LANGUAGE_DEPS_LOG" || {
		echo "$label stopped before attempting: $final_command" >&2
		cat "$LANGUAGE_DEPS_LOG" >&2
		exit 1
	}
}

assert_failed_after_attempting \
	"Node dependencies" \
	"npm install --global --ignore-scripts @earendil-works/pi-coding-agent" \
	install_node_deps <<<"interactive input"
grep -Fq \
	'npm install --global --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code' \
	"$LANGUAGE_DEPS_LOG"
if grep -Fq 'npm consumed stdin:' "$LANGUAGE_DEPS_LOG"; then
	echo "Node dependency installer left npm attached to interactive stdin" >&2
	cat "$LANGUAGE_DEPS_LOG" >&2
	exit 1
fi

# GitHub runner images can already include Java/Kotlin/Gradle. Keep this test
# focused on SDKMAN failure resilience by forcing those command checks to miss.
command() {
	if [[ "${1:-}" == "-v" ]]; then
		case "${2:-}" in
			java | kotlin | gradle) return 1 ;;
		esac
	fi
	builtin command "$@"
}
assert_failed_after_attempting \
	"SDKMAN dependencies" \
	"sdk install gradle" \
	install_sdkman_deps <<<"interactive input"
if grep -Fq 'sdk consumed stdin:' "$LANGUAGE_DEPS_LOG"; then
	echo "SDKMAN dependency installer left sdk attached to interactive stdin" >&2
	cat "$LANGUAGE_DEPS_LOG" >&2
	exit 1
fi
unset -f command

assert_failed_after_attempting \
	"Rust dependencies" \
	"cargo install --locked watchexec-cli" \
	install_rust_deps

# Exercise the Apple-Bash boundary without requiring a Bash 3 CI runner:
# pretend the parent is incompatible, then verify that SDKMAN is initialized
# only after install_sdkman_deps delegates to a fresh modern-Bash process.
if ((BASH_VERSINFO[0] >= 4)); then
	sdkman_fixture="$fixture_dir/sdkman"
	mkdir -p "$sdkman_fixture/bin" "$sdkman_fixture/sdkman/bin"
	ln -s "$BASH" "$sdkman_fixture/bin/bash"
	ln -s "$(command -v dirname)" "$sdkman_fixture/bin/dirname"
	cat >"$sdkman_fixture/sdkman/bin/sdkman-init.sh" <<'EOF'
printf 'sdkman init bash %s\n' "${BASH_VERSINFO[0]}" >>"$LANGUAGE_DEPS_LOG"
sdk() {
	printf 'sdk %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
	printf 'sdk auto answer %s\n' "${sdkman_auto_answer:-unset}" >>"$LANGUAGE_DEPS_LOG"
}
EOF

	(
		export PATH="$sdkman_fixture/bin"
		export SDKMAN_DIR="$sdkman_fixture/sdkman"
		export SDKMAN_TEST_MODERN_BASH="$BASH"
		sdkman_current_bash_is_compatible() { return 1; }
		sdkman_compatible_bash() { printf '%s\n' "$SDKMAN_TEST_MODERN_BASH"; }

		: >"$LANGUAGE_DEPS_LOG"
		install_sdkman
		if grep -Fq 'sdkman init' "$LANGUAGE_DEPS_LOG"; then
			echo "SDKMAN was sourced into the simulated legacy-Bash parent" >&2
			exit 1
		fi
		install_sdkman_deps
	)

	grep -Eq 'sdkman init bash ([4-9]|[1-9][0-9]+)$' "$LANGUAGE_DEPS_LOG"
	grep -Fq 'sdk install java' "$LANGUAGE_DEPS_LOG"
	grep -Fq 'sdk install gradle' "$LANGUAGE_DEPS_LOG"
	grep -Fq 'sdk auto answer true' "$LANGUAGE_DEPS_LOG"
fi

echo "Language dependency resilience tests passed."
