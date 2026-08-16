#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture=$(mktemp -d /tmp/dotfiles-nvim-auth.XXXXXX)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/bin" "$fixture/repo"
git -C "$fixture/repo" init --quiet
git -C "$fixture/repo" remote add origin https://github.com/petalas/nvim.git

cat >"$fixture/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GH_AUTH_CALLS"
case "$1 $2" in
    "auth status") [[ -f "$GH_AUTHENTICATED" ]] ;;
    "auth login") touch "$GH_AUTHENTICATED" ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$fixture/bin/gh"

# shellcheck source=../lib/nvim-sync.sh disable=SC1091
source "$repo_dir/lib/nvim-sync.sh"

export GH_AUTH_CALLS="$fixture/calls"
export GH_AUTHENTICATED="$fixture/authenticated"
export PATH="$fixture/bin:$PATH"

# A logged-in gh account is accepted without starting another login flow.
touch "$GH_AUTHENTICATED"
_nvim_sync_ensure_github_auth "$fixture/repo"
grep -qx 'auth status --hostname github.com' "$GH_AUTH_CALLS"
if grep -q '^auth login ' "$GH_AUTH_CALLS"; then
    echo 'authenticated flow unexpectedly started a new login' >&2
    exit 1
fi

# Without a session, an unattended run gives a deterministic failure instead
# of allowing Git to fall back to a username prompt.
rm -f "$GH_AUTHENTICATED"
: >"$GH_AUTH_CALLS"
if DOTFILES_NONINTERACTIVE=1 _nvim_sync_ensure_github_auth "$fixture/repo"; then
    echo 'unattended flow unexpectedly accepted missing authentication' >&2
    exit 1
fi
if grep -q '^auth login ' "$GH_AUTH_CALLS"; then
    echo 'unattended flow unexpectedly tried an interactive login' >&2
    exit 1
fi

# Non-GitHub remotes do not require gh and keep local synchronization tests
# and arbitrary local forks independent of GitHub authentication.
git -C "$fixture/repo" remote set-url origin "$fixture/local.git"
: >"$GH_AUTH_CALLS"
_nvim_sync_ensure_github_auth "$fixture/repo"
[[ ! -s "$GH_AUTH_CALLS" ]]

# Network operations inject gh's credential helper without changing the
# user's managed global Git configuration, and disable Git's own prompt.
cat >"$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$GIT_TERMINAL_PROMPT" >"$GIT_NETWORK_PROMPT"
printf '%s\n' "$@" >"$GIT_NETWORK_ARGS"
EOF
chmod +x "$fixture/bin/git"
export GIT_NETWORK_PROMPT="$fixture/git-prompt"
export GIT_NETWORK_ARGS="$fixture/git-args"
_nvim_sync_git_network "$fixture/repo" fetch --quiet origin
grep -qx '0' "$GIT_NETWORK_PROMPT"
grep -qx 'credential.https://github.com.helper=' "$GIT_NETWORK_ARGS"
grep -qx 'credential.https://github.com.helper=!gh auth git-credential' "$GIT_NETWORK_ARGS"
grep -qx 'fetch' "$GIT_NETWORK_ARGS"
grep -qx 'origin' "$GIT_NETWORK_ARGS"

echo 'Nvim GitHub authentication tests passed.'
