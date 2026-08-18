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

# Repository identity is independent of the GitHub transport spelling.
identity_checkout="$fixture_dir/identity-checkout"
git init --quiet "$identity_checkout"
git -C "$identity_checkout" remote add origin git@github.com:petalas/nvim.git
_git_origin_matches "$identity_checkout" https://github.com/petalas/nvim.git
git -C "$identity_checkout" remote set-url origin ssh://git@github.com/petalas/nvim.git
_git_origin_matches "$identity_checkout" https://github.com/petalas/nvim.git
git -C "$identity_checkout" remote set-url origin https://github.com/petalas/nvim.git
_git_origin_matches "$identity_checkout" git@github.com:petalas/nvim.git
git -C "$identity_checkout" remote set-url origin ssh://git@github.com/petalas/nvim.git
if _git_origin_matches "$identity_checkout" https://github.com/someone-else/nvim.git; then
    echo "origin validation accepted a different GitHub repository owner" >&2
    exit 1
fi

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

# Existing clones must retain the expected origin, branch, and clean state.
remote="$fixture_dir/remote.git"
seed="$fixture_dir/seed"
checkout="$fixture_dir/checkout"
git init --bare --initial-branch=main "$remote" >/dev/null
git clone --quiet "$remote" "$seed"
git -C "$seed" config user.name Test
git -C "$seed" config user.email test@example.com
printf 'managed\n' >"$seed/file"
mkdir "$seed/vendor"
printf 'tracked parent\n' >"$seed/vendor/.keep"
git -C "$seed" add file vendor/.keep
git -C "$seed" commit --quiet -m initial
git -C "$seed" push --quiet origin main
clone_or_ff "$remote" "$checkout" main

nested_remote="$fixture_dir/nested.git"
git init --bare --initial-branch=main "$nested_remote" >/dev/null
git clone --quiet "$nested_remote" "$checkout/vendor/tool"
clone_or_ff_with_nested "$remote" "$checkout" main vendor/tool "$nested_remote"
printf 'nested change\n' >"$checkout/vendor/tool/local"
if clone_or_ff_with_nested "$remote" "$checkout" main vendor/tool "$nested_remote"; then
    echo "clone_or_ff accepted a dirty managed nested checkout" >&2
    exit 1
fi
rm "$checkout/vendor/tool/local"
git -C "$checkout/vendor/tool" remote set-url origin "$fixture_dir/wrong-nested.git"
if clone_or_ff_with_nested "$remote" "$checkout" main vendor/tool "$nested_remote"; then
    echo "clone_or_ff accepted the wrong managed nested origin" >&2
    exit 1
fi
git -C "$checkout/vendor/tool" remote set-url origin "$nested_remote"

printf 'untracked\n' >"$checkout/local"
if clone_or_ff_with_nested "$remote" "$checkout" main vendor/tool "$nested_remote"; then
    echo "clone_or_ff accepted a dirty checkout" >&2
    exit 1
fi
rm "$checkout/local"
git -C "$checkout" remote set-url origin "$fixture_dir/wrong.git"
if clone_or_ff_with_nested "$remote" "$checkout" main vendor/tool "$nested_remote"; then
    echo "clone_or_ff accepted an unexpected origin" >&2
    exit 1
fi

echo "Git synchronization retry and checkout validation tests passed."
