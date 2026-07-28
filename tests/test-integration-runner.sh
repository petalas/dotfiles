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
if [[ -n "${DOCKER_FAIL_UNTIL:-}" ]]; then
	count=0
	[[ ! -f "$DOCKER_ATTEMPTS_FILE" ]] || count=$(cat "$DOCKER_ATTEMPTS_FILE")
	count=$((count + 1))
	printf '%s\n' "$count" >"$DOCKER_ATTEMPTS_FILE"
	((count >= DOCKER_FAIL_UNTIL))
fi
EOF
cat >"$fixture_dir/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture_dir/bin/docker" "$fixture_dir/bin/sleep"

assert_arg() {
	local expected="$1"
	grep -Fxq -- "$expected" "$DOCKER_ARGS_FILE" || {
		echo "Expected Docker arguments to contain: $expected" >&2
		exit 1
	}
}

assert_no_arg() {
	local unexpected="$1"
	if grep -Fxq -- "$unexpected" "$DOCKER_ARGS_FILE"; then
		echo "Expected Docker arguments not to contain: $unexpected" >&2
		exit 1
	fi
}

export PATH="$fixture_dir/bin:$PATH"
export DOCKER_ARGS_FILE="$fixture_dir/docker-args"
unset DOCKER_PLATFORM

"$repo_dir/tests/integration/run.sh" ubuntu >/dev/null
assert_arg '--pull'
assert_arg '--target'
assert_arg 'integration'
assert_arg 'BASE_IMAGE=ubuntu:24.04'
assert_arg 'DISTRO=ubuntu'

INTEGRATION_PULL=0 "$repo_dir/tests/integration/run.sh" ubuntu >/dev/null
assert_no_arg '--pull'

DOCKER_PLATFORM=linux/arm64 "$repo_dir/tests/integration/run.sh" debian >/dev/null
assert_arg 'linux/arm64'
assert_arg 'BASE_IMAGE=debian:trixie-slim'
assert_arg 'DISTRO=debian'

"$repo_dir/tests/integration/run.sh" debian-bookworm >/dev/null
assert_arg 'BASE_IMAGE=debian:bookworm-slim'
assert_arg 'DISTRO=debian'

"$repo_dir/tests/integration/run.sh" bootstrap >/dev/null
assert_arg 'bootstrap'
assert_arg 'BASE_IMAGE=debian:trixie-slim'

"$repo_dir/tests/integration/run.sh" arch >/dev/null
assert_arg 'linux/amd64'
assert_arg 'DISTRO=arch'

export DOCKER_ATTEMPTS_FILE="$fixture_dir/docker-attempts"
DOCKER_FAIL_UNTIL=3 "$repo_dir/tests/integration/run.sh" ubuntu >/dev/null 2>&1
[[ "$(cat "$DOCKER_ATTEMPTS_FILE")" == 3 ]] || {
	echo "Integration runner did not retry the Docker build three times" >&2
	exit 1
}

: >"$DOCKER_ATTEMPTS_FILE"
if DOCKER_FAIL_UNTIL=4 "$repo_dir/tests/integration/run.sh" ubuntu >/dev/null 2>&1; then
	echo "Integration runner accepted a Docker build that failed three times" >&2
	exit 1
fi
[[ "$(cat "$DOCKER_ATTEMPTS_FILE")" == 3 ]] || {
	echo "Integration runner exceeded its three-attempt bound" >&2
	exit 1
}

echo "Integration runner policy tests passed."
