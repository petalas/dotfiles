#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-integration-runner.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-integration-runner.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture_dir/bin"
cat >"$fixture_dir/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$DOCKER_ARGS_FILE"
EOF
chmod +x "$fixture_dir/bin/docker"

assert_arg() {
	local expected="$1"
	grep -Fxq -- "$expected" "$DOCKER_ARGS_FILE" || {
		echo "Expected Docker arguments to contain: $expected" >&2
		exit 1
	}
}

assert_no_mirror_args() {
	if grep -Eq '^APT_(PRIMARY|SECURITY)_MIRROR=' "$DOCKER_ARGS_FILE"; then
		echo "Expected Docker arguments not to contain mirror overrides" >&2
		exit 1
	fi
}

export PATH="$fixture_dir/bin:$PATH"
export DOCKER_ARGS_FILE="$fixture_dir/docker-args"
unset APT_PRIMARY_MIRROR APT_SECURITY_MIRROR

"$repo_dir/tests/integration/run.sh" ubuntu >/dev/null
assert_no_mirror_args

APT_PRIMARY_MIRROR=http://primary.example.com/ubuntu \
	APT_SECURITY_MIRROR=http://security.example.com/ubuntu \
	"$repo_dir/tests/integration/run.sh" ubuntu >/dev/null
assert_arg 'APT_PRIMARY_MIRROR=http://primary.example.com/ubuntu'
assert_arg 'APT_SECURITY_MIRROR=http://security.example.com/ubuntu'

echo "Integration runner mirror policy tests passed."
