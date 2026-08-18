#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d /tmp/dotfiles-easy-install.XXXXXX)
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/bin" "$fixture_dir/home" "$fixture_dir/lib" "$fixture_dir/tools"
cp "$repo_dir/easy-install.sh" "$fixture_dir/easy-install.sh"
cp "$repo_dir/lib/platform.sh" "$fixture_dir/lib/platform.sh"

cat >"$fixture_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_SUDO_LOG"
if [[ "${1:-}" == -n && "${2:-}" == true ]]; then
    [[ -e "$TEST_SUDO_STATE" ]]
    exit
fi
if [[ "${1:-}" == -k ]]; then
    exit
fi
if [[ "${1:-}" == sh && "${2:-}" == -c ]]; then
    [[ "${TEST_SCENARIO:-}" != sudo_denied ]] || exit 1
    [[ "${6:-}" == /etc/sudoers.d/zz-dotfiles-* ]]
    [[ "${7:-}" == /etc/sudoers.d/dotfiles-* ]]
    grep -Eq '^\\#[0-9]+ ALL=\(ALL:ALL\) NOPASSWD: ALL$' "$5"
    cp "$5" "$TEST_SUDOERS_CAPTURE"
    touch "$TEST_SUDO_STATE"
    exit
fi
exit 1
EOF
for command_name in curl git; do
    cat >"$fixture_dir/bin/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
done
cat >"$fixture_dir/lib/install-plan" <<'EOF'
#!/usr/bin/env bash
command=$1
shift
printf '%s %s\n' "$command" "$*" >>"$TEST_STEPS"
case "$command" in
    inspect)
        while (($#)); do
            if [[ "$1" == --output ]]; then printf 'format\t1\nos\tmacos\n' >"$2"; break; fi
            shift
        done
        ;;
    prepare)
        [[ "${NONINTERACTIVE:-0}" == 0 ]]
        [[ "${TEST_SCENARIO:-}" != prepare_failure ]] || exit 1
        while (($#)); do
            if [[ "$1" == --output ]]; then printf 'plan\n' >"$2"; break; fi
            shift
        done
        ;;
    execute|apply)
        [[ "${NONINTERACTIVE:-}" == 1 ]]
        [[ "${DOTFILES_NONINTERACTIVE:-}" == 1 ]]
        if IFS= read -r _; then echo 'apply stdin was open' >&2; exit 1; fi
        [[ "${TEST_SCENARIO:-}" != apply_failure ]]
        ;;
esac
EOF
cat >"$fixture_dir/tools/run-install-tui" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == run && "$2" == -- ]]; then shift 2; exec "$@"; fi
exit 1
EOF
chmod +x "$fixture_dir/bin"/* "$fixture_dir/lib/install-plan" "$fixture_dir/tools/run-install-tui" "$fixture_dir/easy-install.sh"

steps="$fixture_dir/steps"
run_install() {
    local scenario=$1
    shift
    : >"$steps"
    rm -f "$fixture_dir/$scenario.sudo-ready" "$fixture_dir/$scenario.sudoers"
    : >"$fixture_dir/$scenario.sudo.log"
    env TEST_SCENARIO="$scenario" TEST_STEPS="$steps" \
        TEST_SUDO_LOG="$fixture_dir/$scenario.sudo.log" \
        TEST_SUDO_STATE="$fixture_dir/$scenario.sudo-ready" \
        TEST_SUDOERS_CAPTURE="$fixture_dir/$scenario.sudoers" \
        HOME="$fixture_dir/home" DOTFILES_OS_OVERRIDE=debian \
        PATH="$fixture_dir/bin:/usr/bin:/bin" \
        "${EASY_INSTALL_TEST_ENTRY_BASH:-$BASH}" "$fixture_dir/easy-install.sh" "$@" \
        >"$fixture_dir/$scenario.log" 2>&1
}

run_install visual
[[ "$(sed -n '1p' "$steps")" == inspect*'--os '* ]]
[[ "$(sed -n '2p' "$steps")" == prepare*'--mode visual'* ]]
[[ "$(sed -n '3p' "$steps")" == execute*'--operation install'* ]]

run_install unattended --unattended
grep -Fq 'prepare --mode full' "$steps"
[[ -s "$fixture_dir/unattended.sudoers" ]]
[[ "$(grep -c '^sh -c ' "$fixture_dir/unattended.sudo.log")" == 1 ]]
grep -Fxq -- '-k' "$fixture_dir/unattended.sudo.log"
grep -Fxq -- '-n true' "$fixture_dir/unattended.sudo.log"

plan="$fixture_dir/custom-plan"
printf 'format=1\n' >"$plan"
run_install replay --plan "$plan"
grep -Fq 'prepare --mode record' "$steps"
grep -Fq -- "--record $plan" "$steps"

if run_install unknown --wat; then
    echo 'Expected unknown option to fail' >&2
    exit 1
fi
[[ ! -s "$steps" ]]

if run_install apply_failure --unattended; then
    echo 'Expected apply failure to propagate' >&2
    exit 1
fi
if run_install prepare_failure --unattended; then
    echo 'Expected prepare failure to stop before apply' >&2
    exit 1
fi
[[ "$(wc -l <"$steps")" == 1 ]]

if run_install sudo_denied --unattended; then
    echo "Expected denied administrator access to stop setup" >&2
    exit 1
fi
[[ ! -s "$steps" ]]
grep -Fq 'Could not configure passwordless sudo' "$fixture_dir/sudo_denied.log"

run_install help --help
grep -Fq 'Usage:' "$fixture_dir/help.log"
[[ ! -s "$steps" ]]

echo "easy-install mode contract tests passed."
