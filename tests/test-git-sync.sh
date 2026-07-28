#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-git-sync.XXXXXX)

cleanup() {
    case "$fixture_dir" in
        /tmp/dotfiles-git-sync.*) rm -r -- "$fixture_dir" ;;
    esac
}
trap cleanup EXIT

# shellcheck source=../lib/git-sync.sh
source "$repo_dir/lib/git-sync.sh"

sleep() { :; }

cat >"$fixture_dir/flaky" <<'EOF'
#!/usr/bin/env bash
count=0
[[ ! -f "$GIT_RETRY_COUNT" ]] || count=$(cat "$GIT_RETRY_COUNT")
count=$((count + 1))
printf '%s\n' "$count" >"$GIT_RETRY_COUNT"
((count >= GIT_RETRY_SUCCEED_ON))
EOF
chmod +x "$fixture_dir/flaky"

export GIT_RETRY_COUNT="$fixture_dir/count"
export GIT_RETRY_SUCCEED_ON=3
_git_retry "fixture operation" "$fixture_dir/flaky"
[[ "$(cat "$GIT_RETRY_COUNT")" == 3 ]] || {
    echo "retry helper did not make three attempts" >&2
    exit 1
}

export GIT_RETRY_SUCCEED_ON=4
: >"$GIT_RETRY_COUNT"
if _git_retry "fixture operation" "$fixture_dir/flaky"; then
    echo "retry helper accepted a command that failed three times" >&2
    exit 1
fi
[[ "$(cat "$GIT_RETRY_COUNT")" == 3 ]] || {
    echo "retry helper exceeded its three-attempt bound" >&2
    exit 1
}

echo "Git synchronization retry tests passed."
