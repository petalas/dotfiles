#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-omp-install.XXXXXX)
trap 'rm -rf "$fixture"' EXIT

# shellcheck source=../installers/install_omp.sh
source "$repo_dir/installers/install_omp.sh"

run_installer_operation() {
    local sub_id=$1 label=$2 operation_result=0
    shift 2

    printf 'operation start %s %s\n' "$sub_id" "$label" >>"$OMP_TEST_LOG"
    "$@" || operation_result=$?
    printf 'operation settled %s %s %s\n' "$sub_id" "$label" "$operation_result" \
        >>"$OMP_TEST_LOG"
    return "$operation_result"
}

prepare_case() {
    local case_name=$1 with_bun=$2 with_managed_omp=$3 with_existing_omp=$4
    local case_dir="$fixture/$case_name"

    mkdir -p "$case_dir/bin" "$case_dir/home/.bun/bin" "$case_dir/repo"
    if [[ "$with_bun" == yes ]]; then
        cat >"$case_dir/bin/bun" <<'EOF'
#!/bin/sh
printf 'bun %s\n' "$*" >>"$OMP_TEST_LOG"
if IFS= read -r unexpected_input; then
    printf 'bun read stdin: %s\n' "$unexpected_input" >>"$OMP_TEST_LOG"
    exit 64
fi
if [ "$*" != 'install --global @oh-my-pi/pi-coding-agent' ]; then
    exit 65
fi
if [ "${OMP_TEST_MODE:-}" = bun-fail ]; then
    printf 'fixture bun failure\n' >&2
    exit 42
fi
EOF
        chmod +x "$case_dir/bin/bun"
    fi
    if [[ "$with_managed_omp" == yes ]]; then
        cat >"$case_dir/home/.bun/bin/omp" <<'EOF'
#!/bin/sh
exit 0
EOF
        chmod +x "$case_dir/home/.bun/bin/omp"
    fi
    if [[ "$with_existing_omp" == yes ]]; then
        cat >"$case_dir/bin/omp" <<'EOF'
#!/bin/sh
exit 0
EOF
        chmod +x "$case_dir/bin/omp"
    fi
    cat >"$case_dir/repo/link-dotfiles.sh" <<'EOF'
#!/bin/sh
if IFS= read -r unexpected_input; then
    printf 'linker read stdin: %s\n' "$unexpected_input" >>"$OMP_TEST_LOG"
    exit 66
fi
omp_path=$(command -v omp) || {
    printf 'linker could not resolve omp\n' >&2
    exit 67
}
printf 'link omp=%s\n' "$omp_path" >>"$OMP_TEST_LOG"
if [ "${OMP_TEST_MODE:-}" = linker-fail ]; then
    printf 'fixture linker failure\n' >&2
    exit 33
fi
EOF
    chmod +x "$case_dir/repo/link-dotfiles.sh"
}

run_case() {
    local case_name=$1 mode=$2
    local case_dir="$fixture/$case_name"

    (
        unset -f bun omp 2>/dev/null || true
        unalias bun omp 2>/dev/null || true
        export HOME="$case_dir/home"
        export PATH="$case_dir/bin"
        export DOTFILES_ROOT="$case_dir/repo"
        export OMP_TEST_LOG="$case_dir/commands"
        export OMP_TEST_MODE="$mode"
        install_omp <<<"interactive input must stay unread"
    ) >"$case_dir/out" 2>"$case_dir/err"
}

prepare_case fresh yes yes no
run_case fresh fresh
cat >"$fixture/fresh/expected" <<EOF
operation start package Install OMP package
bun install --global @oh-my-pi/pi-coding-agent
operation settled package Install OMP package 0
operation start dotfiles Link and configure OMP
link omp=$fixture/fresh/home/.bun/bin/omp
operation settled dotfiles Link and configure OMP 0
EOF
cmp -s "$fixture/fresh/expected" "$fixture/fresh/commands"
[[ "$(install_omp_operations)" == $'package\tInstall OMP package\ndotfiles\tLink and configure OMP' ]]

prepare_case missing-bun no no no
if run_case missing-bun fresh; then
    echo "Expected installation without Bun to fail" >&2
    exit 1
fi
grep -Fq 'OMP installation requires Bun; install Bun first.' "$fixture/missing-bun/err"
if grep -Fq 'operation start dotfiles' "$fixture/missing-bun/commands"; then
    echo "OMP linking ran after the missing-Bun failure" >&2
    exit 1
fi

prepare_case bun-failure yes yes no
if run_case bun-failure bun-fail; then
    echo "Expected Bun package installation failure to propagate" >&2
    exit 1
fi
grep -Fq 'fixture bun failure' "$fixture/bun-failure/err"
if grep -Fq 'operation start dotfiles' "$fixture/bun-failure/commands"; then
    echo "OMP linking ran after Bun failed" >&2
    exit 1
fi

prepare_case missing-omp yes no no
if run_case missing-omp fresh; then
    echo "Expected a missing post-install OMP command to fail" >&2
    exit 1
fi
grep -Fq 'OMP was installed but is not available on PATH.' "$fixture/missing-omp/err"
if grep -Fq 'operation start dotfiles' "$fixture/missing-omp/commands"; then
    echo "OMP linking ran before package verification succeeded" >&2
    exit 1
fi

prepare_case existing no no yes
run_case existing fresh
cat >"$fixture/existing/expected" <<EOF
operation start package Install OMP package
operation settled package Install OMP package 0
operation start dotfiles Link and configure OMP
link omp=$fixture/existing/bin/omp
operation settled dotfiles Link and configure OMP 0
EOF
cmp -s "$fixture/existing/expected" "$fixture/existing/commands"

prepare_case linker-failure no no yes
if run_case linker-failure linker-fail; then
    echo "Expected OMP linker failure to propagate" >&2
    exit 1
fi
grep -Fxq 'link omp='"$fixture/linker-failure/bin/omp" "$fixture/linker-failure/commands"
grep -Fxq 'operation settled dotfiles Link and configure OMP 33' \
    "$fixture/linker-failure/commands"
grep -Fq 'fixture linker failure' "$fixture/linker-failure/err"

printf 'OMP installer tests passed.\n'
