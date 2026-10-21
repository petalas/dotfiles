#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-update-plan.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/.git" "$fixture/repo/lib" "$fixture/bin" "$fixture/home"
cp "$repo_dir/update-dotfiles" "$fixture/repo/update-dotfiles"
cp "$repo_dir/lib/update-report.sh" "$fixture/repo/lib/update-report.sh"
# Version snapshots parse JSON; the restricted PATH below omits Homebrew's bin.
ln -s "$(command -v jq)" "$fixture/bin/jq"
cat >"$fixture/repo/link-dotfiles.sh" <<'EOF'
#!/usr/bin/env bash
theme_source="$DOTFILES_DIR/dot/.config/ghostty/themes/seashells-light"
[[ -f "$theme_source" ]] || exit 31
mkdir -p "$HOME/.config/ghostty/themes"
ln -sfn "$theme_source" "$HOME/.config/ghostty/themes/seashells-light"
printf 'link managed themes\n' >>"$UPDATE_TEST_LOG"
EOF
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
    printf 'Yazi packages\n' >>"$DOTFILES_UPDATE_FAILURES_FILE"
    exit 23
fi
EOF
cat >"$fixture/repo/lib/packages.sh" <<'EOF'
linux_github_cli_installed() { [[ "${GH_PACKAGE_INSTALLED:-1}" == 1 ]]; }
linux_github_cli_prepare_repository() {
    printf 'gh repository\n' >>"$UPDATE_TEST_LOG"
    [[ "${GH_REPOSITORY_FAIL:-0}" == 0 ]]
}
linux_packages_upgrade() { printf 'system upgrade\n' >>"$UPDATE_TEST_LOG"; }
EOF
cat >"$fixture/repo/lib/platform.sh" <<'EOF'
dotfiles_os() { echo debian; }
EOF
cat >"$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *'status --porcelain') : ;;
    *'rev-parse --short HEAD') cat "$2/.git/fixture-revision" 2>/dev/null || printf 'aaaaaaa\n' ;;
    *'pull --ff-only')
        mkdir -p "$DOTFILES_DIR/dot/.config/ghostty/themes"
        printf 'new managed theme\n' >"$DOTFILES_DIR/dot/.config/ghostty/themes/seashells-light"
        printf 'bbbbbbb\n' >"$DOTFILES_DIR/.git/fixture-revision"
        ;;
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
case "$*" in
    --version) printf '1.0.0\n'; exit 0 ;;
    list) printf 'No packages installed.\n'; exit 0 ;;
esac
printf 'pi %s\n' "$*" >>"$UPDATE_TEST_LOG"
[[ "$*" == 'update --all' ]]
EOF
cat >"$fixture/bin/omp" <<'EOF'
#!/usr/bin/env bash
printf 'omp %s\n' "$*" >>"$UPDATE_TEST_LOG"
if [[ "$*" != update ]]; then
    exit 2
fi
EOF
cat >"$fixture/bin/bun" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == --version ]]; then
    cat "$HOME/.bun-version" 2>/dev/null || printf '1.0.0\n'
    exit 0
fi
[[ "$*" == upgrade ]] || exit 2
[[ "${GITHUB_TOKEN:-}" == fixture-github-token ]] || {
    printf 'Bun did not receive the authenticated GitHub token\n' >&2
    exit 19
}
printf 'bun upgrade\n' >>"$UPDATE_TEST_LOG"
printf '1.1.0\n' >"$HOME/.bun-version"
printf 'bun diagnostic stdout\n'
printf 'bun diagnostic stderr\n' >&2
EOF
# The skills step runs the repository's updater tool only when npx exists.
mkdir -p "$fixture/repo/tools"
cat >"$fixture/repo/tools/update-ai-skills" <<'EOF'
#!/usr/bin/env bash
printf 'update-ai-skills\n' >>"$UPDATE_TEST_LOG"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$fixture/bin/npx"
chmod +x "$fixture/repo/update-dotfiles" "$fixture/repo/link-dotfiles.sh" \
    "$fixture/repo/lib/install-plan" "$fixture/repo/tools/update-ai-skills" \
    "$fixture/bin/git" "$fixture/bin/gh" "$fixture/bin/pi" "$fixture/bin/omp" \
    "$fixture/bin/bun" "$fixture/bin/npx"

mkdir -p "$fixture/home/.config/nvim/.git"
cat >"$fixture/repo/lib/nvim-sync.sh" <<'EOF'
nvim_sync_fork() {
    [[ "$2" == config ]] || return 2
    printf 'nvim config\n' >>"$UPDATE_TEST_LOG"
    [[ "${NVIM_SYNC_FAIL:-0}" == 0 ]]
}
nvim_update_plugins() { printf 'nvim plugins\n' >>"$UPDATE_TEST_LOG"; }
EOF

# SDKMAN can disable its own updater while candidate maintenance stays enabled.
mkdir -p "$fixture/home/.sdkman/bin" "$fixture/home/.sdkman/etc"
printf 'sdkman_selfupdate_feature=false\nsdkman_auto_answer=true\n' >"$fixture/home/.sdkman/etc/config"
cat >"$fixture/home/.sdkman/bin/sdkman-init.sh" <<'EOF'
source "$SDKMAN_DIR/etc/config"
sdk() {
    source "$SDKMAN_DIR/etc/config"
    if [[ $1 == selfupdate && $sdkman_selfupdate_feature != true ]]; then
        print 'Invalid command: selfupdate'
        return 0
    fi
    case $1 in
        version) print 'SDKMAN!\nscript: 5.0.0'; return 0 ;;
        current) print 'Current default versions:\njava 21.0.1-tem'; return 0 ;;
    esac
    print -r -- "sdk $*" >>"$UPDATE_TEST_LOG"
    [[ ${SDK_TEST_FAIL:-} != "$1" ]]
}
EOF
cat >"$fixture/bin/pnpm" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    'ls -g --depth=0 --json')
        [[ ${PNPM_TEST_FAIL:-} != list ]] || { echo 'pnpm inventory failed' >&2; exit 12; }
        printf '[{"path":"%s/global/5","dependencies":{"example":{"version":"2.0.0"}}}]\n' "$PNPM_HOME"
        ;;
    'update -g --latest')
        case ":$PATH:" in
            *":$PNPM_HOME/bin:"*) printf 'pnpm globals updated\n' >>"$UPDATE_TEST_LOG" ;;
            *) echo 'ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH' >&2; exit 13 ;;
        esac
        ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$fixture/bin/pnpm"
export PNPM_HOME="$fixture/home/custom pnpm"

# The managed global binary is intentionally absent from the inherited PATH.
# A project-local vp must never become the global self-update target.
mkdir -p "$fixture/home/.vite-plus/bin"
cat >"$fixture/home/.vite-plus/bin/vp" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == --version ]]; then
    printf 'vp v%s\n\nLocal vite-plus:\n  vite-plus  Not found\n' "$(cat "$HOME/.vite-plus/version" 2>/dev/null || echo 1.0.0)"
    exit 0
fi
[[ "$*" == upgrade && "${VP_HOME:-}" == "$HOME/.vite-plus" ]] || exit 41
[[ "${CI:-}" == true && "${VP_NODE_MANAGER:-}" == no && "${VP_PM_MANAGER:-}" == no ]] || exit 42
[[ "$PATH" == "$VP_HOME/bin:"* ]] || exit 43
if read -r unexpected_input; then
    echo 'Vite+ upgrade inherited interactive input' >&2
    exit 44
fi
if [[ "${VP_TEST_FAIL:-0}" == 1 ]]; then
    echo 'Vite+ upgrade failed' >&2
    exit 45
fi
printf '1.2.0\n' >"$VP_HOME/version"
EOF
cat >"$fixture/bin/vp" <<'EOF'
#!/usr/bin/env bash
printf 'project-local vp invoked\n' >>"$UPDATE_TEST_LOG"
exit 46
EOF
cat >"$fixture/home/.vite-plus/env" <<'EOF'
printf 'Vite+ environment sourced\n' >>"$UPDATE_TEST_LOG"
EOF
chmod +x "$fixture/home/.vite-plus/bin/vp" "$fixture/bin/vp"

log="$fixture/update.log"
printf 'unexpected interactive input\n' >"$fixture/input"
zsh_bin=$(command -v zsh)
# Run the updater against the fixture only. Every location the updater derives
# from the environment is pinned here; GitHub's Ubuntu runners export
# XDG_CONFIG_HOME, so overriding HOME alone would leave the Neovim fixture
# unreachable. Extra VAR=value arguments select a scenario.
run_updater() {
    env -u GITHUB_TOKEN -u GITHUB_ACCESS_TOKEN -u GH_TOKEN \
        DOTFILES_DIR="$fixture/repo" HOME="$fixture/home" XDG_CONFIG_HOME="$fixture/home/.config" \
        SDKMAN_DIR="$fixture/home/.sdkman" PATH="$fixture/bin:/bin:/usr/bin" \
        VP_HOME="$fixture/home/unmanaged-vite-plus" VP_NODE_MANAGER=yes VP_PM_MANAGER=yes CI=false "$@" \
        "$zsh_bin" "$fixture/repo/update-dotfiles"
}
if ! run_updater UPDATE_TEST_LOG="$log" XDG_STATE_HOME="$fixture/state" <"$fixture/input" >"$fixture/out" 2>"$fixture/err"; then
    cat "$fixture/out" >&2
    cat "$fixture/err" >&2
    exit 1
fi
grep -Fq 'plan prepare --mode defaults' "$log"
grep -Fq 'plan apply --operation reconcile' "$log"
if [[ "$OSTYPE" == linux* ]]; then
    grep -Fxq 'system upgrade' "$log"
    grep -Fxq 'gh repository' "$log"
    [[ $(grep -n '^gh repository$' "$log" | cut -d: -f1) -lt \
        $(grep -n '^system upgrade$' "$log" | cut -d: -f1) ]]
elif grep -Fq 'system upgrade' "$log"; then
    echo "Unexpected Linux system upgrade on $OSTYPE" >&2
    exit 1
fi
[[ "$(grep -c '^plan apply ' "$log")" == 1 ]]
grep -Fxq 'bun upgrade' "$log"
grep -Fxq 'pi update --all' "$log"
if grep -Fq 'omp ' "$log"; then
    echo 'Updater invoked the retired OMP command.' >&2
    exit 1
fi
grep -Fxq 'update-ai-skills' "$log"
grep -Fxq 'nvim plugins' "$log"
grep -Fxq 'pnpm globals updated' "$log"
grep -Fxq 'sdk update' "$log"
grep -Fxq 'sdk upgrade' "$log"
latest_update_log="$fixture/state/dotfiles/latest-update.log"
grep -Fq 'Skipping SDKMAN self-update because sdkman_selfupdate_feature is disabled.' "$latest_update_log"
if grep -Fq 'Invalid command: selfupdate' "$latest_update_log"; then
    echo 'Updater invoked disabled SDKMAN selfupdate' >&2
    exit 1
fi
managed_theme="$fixture/home/.config/ghostty/themes/seashells-light"
[[ -L "$managed_theme" ]]
[[ "$(readlink "$managed_theme")" == "$fixture/repo/dot/.config/ghostty/themes/seashells-light" ]]
grep -Fxq 'link managed themes' "$log"
[[ "$(cat "$fixture/home/.vite-plus/version")" == 1.2.0 ]]
if grep -Eq 'project-local vp invoked|Vite\+ environment sourced' "$log"; then
    echo 'Vite+ maintenance used a project CLI or sourced runtime ownership settings' >&2
    exit 1
fi

[[ -f "$latest_update_log" ]]
if stat -c '%a' "$latest_update_log" >/dev/null 2>&1; then
    log_mode=$(stat -c '%a' "$latest_update_log")
else
    log_mode=$(stat -f '%Lp' "$latest_update_log")
fi
[[ "$log_mode" == 600 ]]
[[ "$(tail -n 1 "$fixture/out")" == "Update log: $latest_update_log" ]]
grep -Fq 'bun diagnostic stdout' "$latest_update_log"
grep -Fq 'bun diagnostic stderr' "$latest_update_log"
# The terminal shows one result line per item and none of the tool output.
grep -Fxq 'Upgraded dotfiles aaaaaaa ==> bbbbbbb' "$fixture/out"
grep -Fxq 'Upgraded bun 1.0.0 ==> 1.1.0' "$fixture/out"
grep -Fxq 'Upgraded vite-plus 1.0.0 ==> 1.2.0' "$fixture/out"
grep -Fxq 'example 2.0.0 ==> already latest' "$fixture/out"
grep -Fxq 'pi 1.0.0 ==> already latest' "$fixture/out"
grep -Fxq 'java 21.0.1-tem ==> already latest' "$fixture/out"
grep -Fxq 'Upgraded bun 1.0.0 ==> 1.1.0' "$latest_update_log"
if grep -Fq 'bun diagnostic' "$fixture/out" "$fixture/err" || [[ -s "$fixture/err" ]]; then
    echo 'Tool output reached the terminal instead of only the update log' >&2
    exit 1
fi
if grep -Fq 'fixture-github-token' "$latest_update_log"; then
    echo "Update log exposed the GitHub token" >&2
    exit 1
fi

# Without credentials, Bun is skipped rather than consuming GitHub's anonymous
# API quota or failing the otherwise healthy update.
no_auth_log="$fixture/no-auth-commands.log"
if ! run_updater GH_TEST_MODE=no-auth UPDATE_TEST_LOG="$no_auth_log" XDG_STATE_HOME="$fixture/no-auth-state" \
    >"$fixture/no-auth-out" 2>"$fixture/no-auth-err"; then
    cat "$fixture/no-auth-out" >&2
    cat "$fixture/no-auth-err" >&2
    exit 1
fi
if grep -Fq 'bun upgrade' "$no_auth_log"; then
    echo "Bun used GitHub anonymously" >&2
    exit 1
fi
grep -Fq "Skipping Bun upgrade to avoid GitHub's anonymous API rate limit." "$fixture/no-auth-state/dotfiles/latest-update.log"
grep -Fxq 'bun 1.1.0 ==> skipped' "$fixture/no-auth-out"

# An absent global CLI is skipped, even when a project-local vp is on PATH.
mv "$fixture/home/.vite-plus/bin/vp" "$fixture/managed-vp"
printf 'not upgraded\n' >"$fixture/home/.vite-plus/version"
if ! run_updater UPDATE_TEST_LOG="$fixture/no-vp.log" XDG_STATE_HOME="$fixture/no-vp-state" \
    >"$fixture/no-vp-out" 2>"$fixture/no-vp-err"; then
    cat "$fixture/no-vp-out" >&2
    cat "$fixture/no-vp-err" >&2
    exit 1
fi
[[ "$(cat "$fixture/home/.vite-plus/version")" == 'not upgraded' ]]
if grep -Eq 'project-local vp invoked|Vite\+ environment sourced' "$fixture/no-vp.log"; then
    echo 'Updater treated a project-local Vite+ CLI as a global installation' >&2
    exit 1
fi
mv "$fixture/managed-vp" "$fixture/home/.vite-plus/bin/vp"

# A failed step keeps its diagnostics and repeats the log path beside the final
# failure summary.
failure_state="$fixture/failure-state"
if run_updater PLAN_APPLY_FAIL=1 NVIM_SYNC_FAIL=1 UPDATE_TEST_LOG="$fixture/failure-commands.log" \
    XDG_STATE_HOME="$failure_state" >"$fixture/failure-out" 2>"$fixture/failure-err"; then
    echo "Expected a failed reconciliation to fail the updater" >&2
    exit 1
fi
failure_log="$failure_state/dotfiles/latest-update.log"
grep -Fq 'fixture reconciliation detail' "$failure_log"
grep -Fxq 'Failed: selected reconciliation, neovim config, Yazi packages' "$fixture/failure-out"
grep -Fxq 'selected reconciliation ==> failed to update' "$fixture/failure-out"
grep -Fxq 'neovim config aaaaaaa ==> failed to update' "$fixture/failure-out"
[[ "$(tail -n 1 "$fixture/failure-out")" == "Update log: $failure_log" ]]

grep -Fq 'Skipped: Neovim plugins because configuration synchronization failed.' "$failure_log"
if grep -Fxq 'nvim plugins' "$fixture/failure-commands.log"; then
    echo 'Plugin update ran after a failed config sync' >&2
    exit 1
fi

# Enabled self-updates run, and tool failures reach the final summary.
printf 'sdkman_selfupdate_feature=true\nsdkman_auto_answer=true\n' >"$fixture/home/.sdkman/etc/config"
if run_updater SDK_TEST_FAIL=selfupdate VP_TEST_FAIL=1 PNPM_TEST_FAIL=list UPDATE_TEST_LOG="$fixture/tool-failures.log" \
    XDG_STATE_HOME="$fixture/tool-failures-state" >"$fixture/tool-failures-out" 2>"$fixture/tool-failures-err"; then
    echo 'Expected SDKMAN, Vite+ and pnpm failures to fail the updater' >&2
    exit 1
fi
grep -Fxq 'sdk selfupdate' "$fixture/tool-failures.log"
grep -Fxq 'sdk upgrade' "$fixture/tool-failures.log"
grep -Fxq 'update-ai-skills' "$fixture/tool-failures.log"
tool_failures_log="$fixture/tool-failures-state/dotfiles/latest-update.log"
grep -Fq 'pnpm inventory failed' "$tool_failures_log"
grep -Fq 'Vite+ upgrade failed' "$tool_failures_log"
grep -Fxq 'Failed: sdkman, vite-plus, pnpm global packages' "$fixture/tool-failures-out"
grep -Fxq 'sdkman 5.0.0 ==> failed to update' "$fixture/tool-failures-out"
grep -Fxq 'vite-plus 1.2.0 ==> failed to update' "$fixture/tool-failures-out"
grep -Fxq 'pnpm global packages ==> failed to update' "$fixture/tool-failures-out"

# An installed but deselected GitHub CLI still receives repository maintenance.
# A missing CLI does not cause installation, and repository failures remain
# visible without suppressing independent system/tool upgrades.
if [[ "$OSTYPE" == linux* ]]; then
    run_updater GH_PACKAGE_INSTALLED=0 UPDATE_TEST_LOG="$fixture/no-gh.log" \
        XDG_STATE_HOME="$fixture/no-gh-state" >"$fixture/no-gh-out" 2>"$fixture/no-gh-err"
    if grep -Fxq 'gh repository' "$fixture/no-gh.log"; then
        echo 'Updater configured GitHub CLI when its package was absent' >&2
        exit 1
    fi
    if run_updater GH_REPOSITORY_FAIL=1 UPDATE_TEST_LOG="$fixture/gh-failure.log" \
        XDG_STATE_HOME="$fixture/gh-failure-state" >"$fixture/gh-failure-out" 2>"$fixture/gh-failure-err"; then
        echo 'Expected a failed GitHub CLI repository migration to fail the updater' >&2
        exit 1
    fi
    grep -Fq 'Failed: GitHub CLI repository' "$fixture/gh-failure-out"
    grep -Fxq 'system upgrade' "$fixture/gh-failure.log"
    grep -Fxq 'pi update --all' "$fixture/gh-failure.log"
fi

# Exercise the actual macOS branch on either host. Only this fixture invocation
# overrides Zsh's OSTYPE; it uses the real Homebrew helper with a fake brew.
cp "$repo_dir/lib/homebrew.sh" "$fixture/repo/lib/homebrew.sh"
cat >"$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >>"$UPDATE_TEST_LOG"
case "$*" in
    update) : ;;
    'outdated --json=v2')
        printf '{"formulae":[{"name":"gh","installed_versions":["2.0.0"],"current_version":"2.1.0","pinned":false}],"casks":[]}\n'
        ;;
    'list --formula --installed-on-request') printf 'gh\njq\n' ;;
    'list --formula --versions') printf 'gh 2.0.0\njq 1.8.1\noniguruma 6.9.10\n' ;;
    'list --cask --versions') printf 'ghostty 1.2.0\n' ;;
    'upgrade --formula gh') : ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$fixture/bin/brew"
env -u GITHUB_TOKEN -u GITHUB_ACCESS_TOKEN -u GH_TOKEN \
    DOTFILES_DIR="$fixture/repo" HOME="$fixture/home" XDG_CONFIG_HOME="$fixture/home/.config" \
    SDKMAN_DIR="$fixture/home/.sdkman" PATH="$fixture/bin:/bin:/usr/bin" \
    UPDATE_TEST_LOG="$fixture/macos.log" XDG_STATE_HOME="$fixture/macos-state" \
    "$zsh_bin" -c 'OSTYPE=darwin; source "$1" --after-dotfiles-pull' zsh "$fixture/repo/update-dotfiles" \
    >"$fixture/macos-out" 2>"$fixture/macos-err"
grep -Fxq 'brew update' "$fixture/macos.log"
grep -Fxq 'brew upgrade --formula gh' "$fixture/macos.log"
grep -Fxq 'Upgraded gh 2.0.0 ==> 2.1.0' "$fixture/macos-out"
grep -Fxq 'jq 1.8.1 ==> already latest' "$fixture/macos-out"
grep -Fxq 'ghostty 1.2.0 ==> already latest' "$fixture/macos-out"
if grep -Fq oniguruma "$fixture/macos-out"; then
    echo 'An unchanged Homebrew dependency was listed' >&2
    exit 1
fi
if grep -Eq '^(system upgrade|gh repository)$' "$fixture/macos.log"; then
    echo 'macOS updater invoked Linux package maintenance' >&2
    exit 1
fi

printf 'Update plan integration tests passed.\n'
