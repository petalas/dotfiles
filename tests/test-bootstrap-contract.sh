#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-bootstrap.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/checkout/.git" "$fixture/home"
cp "$repo_dir/bootstrap.sh" "$fixture/bootstrap.sh"
cat >"$fixture/checkout/easy-install.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$BOOTSTRAP_ARGS_LOG"
EOF
cat >"$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BOOTSTRAP_SUDO_LOG"
if [[ "${1:-}" == -n && "${2:-}" == true ]]; then
    [[ -e "$BOOTSTRAP_SUDO_STATE" ]]
elif [[ "${1:-}" == -v ]]; then
    touch "$BOOTSTRAP_SUDO_STATE"
else
    exit 1
fi
EOF
cat >"$fixture/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Linux\n'
EOF
cat >"$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *'remote get-url origin') echo 'https://github.com/petalas/dotfiles.git' ;;
    *'branch --show-current') echo main ;;
    *'status --porcelain') : ;;
    *'pull --ff-only') : ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$fixture/bootstrap.sh" "$fixture/checkout/easy-install.sh" "$fixture/bin"/*

run_bootstrap() {
    local log=$1
    shift
    rm -f "$fixture/sudo-ready"
    : >"$fixture/sudo.log"
    BOOTSTRAP_ARGS_LOG="$log" BOOTSTRAP_SUDO_LOG="$fixture/sudo.log" \
        BOOTSTRAP_SUDO_STATE="$fixture/sudo-ready" \
        DOTFILES_DIR="$fixture/checkout" HOME="$fixture/home" \
        PATH="$fixture/bin:/usr/bin:/bin" bash "$fixture/bootstrap.sh" "$@" \
        >"$fixture/out" 2>"$fixture/err"
}
run_bootstrap "$fixture/default"
[[ "$(cat "$fixture/default")" == '' ]]
grep -Fxq -- '-v' "$fixture/sudo.log"
run_bootstrap "$fixture/unattended" --unattended
[[ "$(cat "$fixture/unattended")" == --unattended ]]
plan="$fixture/plan"
printf 'format=1\n' >"$plan"
run_bootstrap "$fixture/plan-args" --plan "$plan"
[[ "$(cat "$fixture/plan-args")" == "--plan $plan" ]]
if run_bootstrap "$fixture/unknown" --wat; then
    echo 'Expected bootstrap to reject unknown arguments' >&2
    exit 1
fi
[[ ! -e "$fixture/unknown" ]]

printf 'Bootstrap forwarding contract tests passed.\n'
