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
[[ "$*" != *typescript* ]]
EOF

cat >"$fixture_dir/bin/sdk" <<'EOF'
#!/usr/bin/env bash
printf 'sdk %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
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
	"npm i -g --ignore-scripts @earendil-works/pi-coding-agent" \
	install_node_deps

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
	install_sdkman_deps
unset -f command

assert_failed_after_attempting \
	"Rust dependencies" \
	"cargo install --locked watchexec-cli" \
	install_rust_deps

echo "Language dependency resilience tests passed."
