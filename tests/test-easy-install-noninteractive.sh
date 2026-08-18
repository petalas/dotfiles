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
[[ "${TEST_SCENARIO:-}" != sudo_failure ]]
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
    env TEST_SCENARIO="$scenario" TEST_STEPS="$steps" HOME="$fixture_dir/home" \
        OSTYPE=darwin-test PATH="$fixture_dir/bin:/usr/bin:/bin" \
        "${EASY_INSTALL_TEST_ENTRY_BASH:-$BASH}" "$fixture_dir/easy-install.sh" "$@" \
        >"$fixture_dir/$scenario.log" 2>&1
}

run_install visual
[[ "$(sed -n '1p' "$steps")" == inspect*'--os '* ]]
[[ "$(sed -n '2p' "$steps")" == prepare*'--mode visual'* ]]
[[ "$(sed -n '3p' "$steps")" == execute*'--operation install'* ]]

run_install unattended --unattended
grep -Fq 'prepare --mode full' "$steps"

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

if run_install sudo_failure --unattended; then
    echo "Expected missing non-interactive sudo to stop setup" >&2
    exit 1
fi
[[ ! -s "$steps" ]]
grep -Fq "requires working 'sudo -n'" "$fixture_dir/sudo_failure.log"

run_install help --help
grep -Fq 'Usage:' "$fixture_dir/help.log"
[[ ! -s "$steps" ]]

echo "easy-install mode contract tests passed."
