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
action	one	npm-package	one-cli
action	one	cargo-package	one-crate
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
grep -Fxq $'event\t1\trun-start\t4' "$fixture/events"
grep -Fxq $'event\t1\toperation-start\taction:0\tInstall One\tindeterminate' "$fixture/events"
grep -Fxq $'event\t1\toperation-settled\taction:0\tsucceeded\t1\t4' "$fixture/events"
grep -Fxq $'event\t1\toperation-start\taction:1\tnpm package one-cli\tindeterminate' "$fixture/events"
grep -Fxq $'event\t1\toperation-settled\taction:1\tsucceeded\t2\t4' "$fixture/events"
grep -Fxq $'event\t1\toperation-start\taction:2\tCargo package one-crate\tindeterminate' "$fixture/events"
grep -Fxq $'event\t1\toperation-settled\taction:2\tsucceeded\t3\t4' "$fixture/events"
grep -Fxq $'event\t1\toperation-start\tverify:0\tVerify One\tindeterminate' "$fixture/events"
grep -Fxq $'event\t1\toperation-settled\tverify:0\tsucceeded\t4\t4' "$fixture/events"
grep -Fxq $'event\t1\trun-settled\tsucceeded\t4\t4' "$fixture/events"
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
grep -Fxq $'event\t1\trun-start\t4' "$fixture/fd-events"
grep -Fxq $'event\t1\trun-settled\tsucceeded\t4\t4' "$fixture/fd-events"

cat >"$fixture/batch-plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	one	on	optional	cli	One
app	two	on	optional	cli	Two
action	one	apt-package	package-one
action	two	apt-package	package-two
EOF
cat >"$fixture/batch-adapter" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/batch-adapter"
DOTFILES_INSTALL_PLAN_EVENTS=1 DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/adapter" \
DOTFILES_INSTALL_PLAN_BATCH_ADAPTER="$fixture/batch-adapter" \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/batch-plan" \
    --report "$fixture/batch-report.tsv" >"$fixture/batch-events"
grep -Fxq $'event\t1\trun-start\t4' "$fixture/batch-events"
grep -Fxq $'event\t1\toperation-start\taction:0\tAPT package package-one\tindeterminate' "$fixture/batch-events"
grep -Fxq $'event\t1\toperation-start\taction:1\tAPT package package-two\tindeterminate' "$fixture/batch-events"
grep -Fxq $'event\t1\toperation-settled\taction:0\tsucceeded\t1\t4' "$fixture/batch-events"
grep -Fxq $'event\t1\toperation-settled\taction:1\tsucceeded\t2\t4' "$fixture/batch-events"
grep -Fxq $'event\t1\trun-settled\tsucceeded\t4\t4' "$fixture/batch-events"

printf 'Operation lifecycle and progress tests passed.\n'
