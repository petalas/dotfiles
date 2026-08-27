#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-update-plan.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/.git" "$fixture/repo/lib" "$fixture/bin" "$fixture/home"
cp "$repo_dir/update-dotfiles" "$fixture/repo/update-dotfiles"
cat >"$fixture/repo/lib/install-plan" <<'EOF'
#!/usr/bin/env bash
printf 'plan %s\n' "$*" >>"$UPDATE_TEST_LOG"
if [[ "$1" == prepare ]]; then
    while (($#)); do
        if [[ "$1" == --output ]]; then printf 'plan\n' >"$2"; break; fi
        shift
    done
elif [[ "$1" == apply && "${PLAN_APPLY_FAIL:-0}" == 1 ]]; then
    printf 'fixture reconciliation detail\n' >&2
    exit 23
fi
EOF
cat >"$fixture/repo/lib/packages.sh" <<'EOF'
linux_packages_upgrade() { printf 'system upgrade\n' >>"$UPDATE_TEST_LOG"; }
EOF
cat >"$fixture/repo/lib/platform.sh" <<'EOF'
dotfiles_os() { echo debian; }
EOF
cat >"$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *'status --porcelain') : ;;
    *'pull --ff-only') : ;;
    *) exit 1 ;;
esac
EOF
cat >"$fixture/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == 'auth token --hostname github.com' ]] || exit 2
[[ "${GH_TEST_MODE:-authenticated}" != no-auth ]] || exit 1
printf 'fixture-github-token\n'
EOF
cat >"$fixture/bin/pi" <<'EOF'
#!/usr/bin/env bash
printf 'pi %s\n' "$*" >>"$UPDATE_TEST_LOG"
[[ "$*" == 'update --all' ]]
EOF
cat >"$fixture/bin/bun" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == upgrade ]] || exit 2
[[ "${GITHUB_TOKEN:-}" == fixture-github-token ]] || {
    printf 'Bun did not receive the authenticated GitHub token\n' >&2
    exit 19
}
printf 'bun upgrade\n' >>"$UPDATE_TEST_LOG"
printf 'bun diagnostic stdout\n'
printf 'bun diagnostic stderr\n' >&2
EOF
chmod +x "$fixture/repo/update-dotfiles" "$fixture/repo/lib/install-plan" "$fixture/bin/git" \
    "$fixture/bin/gh" "$fixture/bin/pi" "$fixture/bin/bun"

log="$fixture/update.log"
zsh_bin=$(command -v zsh)
if ! env -u GITHUB_TOKEN -u GITHUB_ACCESS_TOKEN -u GH_TOKEN \
    UPDATE_TEST_LOG="$log" DOTFILES_DIR="$fixture/repo" HOME="$fixture/home" \
    XDG_STATE_HOME="$fixture/state" SDKMAN_DIR="$fixture/home/.sdkman" PATH="$fixture/bin:/bin:/usr/bin" \
    "$zsh_bin" "$fixture/repo/update-dotfiles" >"$fixture/out" 2>"$fixture/err"; then
    cat "$fixture/out" >&2
    cat "$fixture/err" >&2
    exit 1
fi
grep -Fq 'plan prepare --mode defaults' "$log"
grep -Fq 'plan apply --operation reconcile' "$log"
if [[ "$OSTYPE" == linux* ]]; then
    grep -Fxq 'system upgrade' "$log"
elif grep -Fq 'system upgrade' "$log"; then
    echo "Unexpected Linux system upgrade on $OSTYPE" >&2
    exit 1
fi
[[ "$(grep -c '^plan apply ' "$log")" == 1 ]]
grep -Fxq 'bun upgrade' "$log"
grep -Fxq 'pi update --all' "$log"

latest_update_log="$fixture/state/dotfiles/latest-update.log"
[[ -f "$latest_update_log" ]]
if stat -c '%a' "$latest_update_log" >/dev/null 2>&1; then
    log_mode=$(stat -c '%a' "$latest_update_log")
else
    log_mode=$(stat -f '%Lp' "$latest_update_log")
fi
[[ "$log_mode" == 600 ]]
grep -Fq "Update log: $latest_update_log" "$fixture/out"
grep -Fq 'bun diagnostic stdout' "$latest_update_log"
grep -Fq 'bun diagnostic stderr' "$latest_update_log"
if grep -Fq 'fixture-github-token' "$latest_update_log"; then
    echo "Update log exposed the GitHub token" >&2
    exit 1
fi

# Without credentials, Bun is skipped rather than consuming GitHub's anonymous
# API quota or failing the otherwise healthy update.
no_auth_log="$fixture/no-auth-commands.log"
if ! env -u GITHUB_TOKEN -u GITHUB_ACCESS_TOKEN -u GH_TOKEN \
    GH_TEST_MODE=no-auth UPDATE_TEST_LOG="$no_auth_log" DOTFILES_DIR="$fixture/repo" HOME="$fixture/home" \
    XDG_STATE_HOME="$fixture/no-auth-state" SDKMAN_DIR="$fixture/home/.sdkman" \
    PATH="$fixture/bin:/bin:/usr/bin" "$zsh_bin" "$fixture/repo/update-dotfiles" \
    >"$fixture/no-auth-out" 2>"$fixture/no-auth-err"; then
    cat "$fixture/no-auth-out" >&2
    cat "$fixture/no-auth-err" >&2
    exit 1
fi
if grep -Fq 'bun upgrade' "$no_auth_log"; then
    echo "Bun used GitHub anonymously" >&2
    exit 1
fi
grep -Fq "Skipping Bun upgrade to avoid GitHub's anonymous API rate limit." "$fixture/no-auth-out"

# A failed step keeps its diagnostics and repeats the log path beside the final
# failure summary.
failure_state="$fixture/failure-state"
if env -u GITHUB_TOKEN -u GITHUB_ACCESS_TOKEN -u GH_TOKEN \
    PLAN_APPLY_FAIL=1 UPDATE_TEST_LOG="$fixture/failure-commands.log" \
    DOTFILES_DIR="$fixture/repo" HOME="$fixture/home" XDG_STATE_HOME="$failure_state" \
    SDKMAN_DIR="$fixture/home/.sdkman" PATH="$fixture/bin:/bin:/usr/bin" \
    "$zsh_bin" "$fixture/repo/update-dotfiles" >"$fixture/failure-out" 2>"$fixture/failure-err"; then
    echo "Expected a failed reconciliation to fail the updater" >&2
    exit 1
fi
failure_log="$failure_state/dotfiles/latest-update.log"
grep -Fq 'fixture reconciliation detail' "$failure_log"
grep -Fq 'Failed: selected reconciliation' "$fixture/failure-err"
grep -Fq "Update log: $failure_log" "$fixture/failure-err"

printf 'Update plan integration tests passed.\n'
