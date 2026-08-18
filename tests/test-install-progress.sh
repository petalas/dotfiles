#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-install-progress.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
cat >"$fixture/plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	one	on	optional	cli	One
action	one	installer	one
EOF
cat >"$fixture/adapter" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/adapter"
DOTFILES_INSTALL_PLAN_EVENTS=1 DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/adapter" \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/plan" \
    --report "$fixture/report.tsv" >"$fixture/events"
grep -Fxq $'event\t1\trun-start\t2' "$fixture/events"
grep -Fxq $'event\t1\toperation-start\tapp:one\tOne\tindeterminate' "$fixture/events"
grep -Fxq $'event\t1\toperation-settled\tapp:one\tsucceeded\t1\t2' "$fixture/events"
grep -Fxq $'event\t1\toperation-settled\tstep:dependencies\tsucceeded\t2\t2' "$fixture/events"
grep -Fxq $'event\t1\trun-settled\tsucceeded\t2\t2' "$fixture/events"
[[ "$(stat -c '%a' "$fixture/report.tsv" 2>/dev/null || stat -f '%Lp' "$fixture/report.tsv")" == 600 ]]
grep -Fxq $'format\t1' "$fixture/report.tsv"
grep -Fxq $'result\tone\tsucceeded' "$fixture/report.tsv"

DOTFILES_INSTALL_PLAN_EVENTS=1 DOTFILES_INSTALL_PLAN_EVENT_FD=3 \
DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/adapter" \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/plan" \
    --report "$fixture/report-fd.tsv" >"$fixture/stdout" 3>"$fixture/fd-events"
if grep -q $'^event\t' "$fixture/stdout"; then
    echo 'Structured events leaked onto stdout despite the dedicated descriptor' >&2
    exit 1
fi
grep -Fxq $'event\t1\trun-start\t2' "$fixture/fd-events"
grep -Fxq $'event\t1\trun-settled\tsucceeded\t2\t2' "$fixture/fd-events"

printf 'Operation lifecycle and progress tests passed.\n'
