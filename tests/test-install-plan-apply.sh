#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-install-apply.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
log="$fixture/actions"

cat >"$fixture/plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
step	links	on	20	Link dotfiles
app	foundation.git	on	required	foundation	Git
app	tools.broken	on	optional	development	Broken
app	tools.dependent	on	optional	development	Dependent
app	tools.independent	on	optional	development	Independent
dependency	tools.dependent	tools.broken
action	foundation.git	provided	git
action	tools.broken	installer	broken
action	tools.dependent	installer	dependent
action	tools.independent	installer	independent
step-action	links	command	./link-dotfiles.sh
EOF
cat >"$fixture/fake-adapter" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$INSTALL_PLAN_TEST_LOG"
[[ "$3" != broken ]]
EOF
chmod +x "$fixture/fake-adapter"

if INSTALL_PLAN_TEST_LOG="$log" DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/fake-adapter" \
    DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/plan" \
    >"$fixture/out" 2>"$fixture/err"; then
    echo "Expected failed selected application to produce nonzero status" >&2
    exit 1
fi
grep -Fxq 'install installer broken ' "$log"
grep -Fxq 'install installer independent ' "$log"
! grep -Fq ' installer dependent ' "$log"
grep -Fq 'failed: tools.broken' "$fixture/err"
grep -Fq 'blocked: tools.dependent' "$fixture/err"
grep -Fq 'succeeded: tools.independent' "$fixture/out"

: >"$log"
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/fake-adapter" INSTALL_PLAN_TEST_LOG="$log" \
    DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 "$repo_dir/lib/install-plan" apply --operation reconcile --plan "$fixture/plan" \
    >"$fixture/reconcile.out" 2>"$fixture/reconcile.err" || true
grep -Fxq 'reconcile installer independent ' "$log"

cat >"$fixture/batch-plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	one	on	optional	cli	One
app	two	on	optional	cli	Two
action	one	apt-package	one
action	two	apt-package	two
EOF
cat >"$fixture/fake-batch" <<'EOF'
#!/usr/bin/env bash
printf 'batch %s %s\n' "$1" "$2" >>"$INSTALL_PLAN_TEST_LOG"
cat "$3" >>"$INSTALL_PLAN_TEST_LOG"
EOF
chmod +x "$fixture/fake-batch"
: >"$log"
DOTFILES_INSTALL_PLAN_BATCH_ADAPTER="$fixture/fake-batch" \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/fake-adapter" INSTALL_PLAN_TEST_LOG="$log" \
    DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/batch-plan" \
    >"$fixture/batch.out" 2>"$fixture/batch.err"
[[ "$(grep -c '^batch install apt-package$' "$log")" == 1 ]]
grep -Fxq $'one\tone\t' "$log"
grep -Fxq $'two\ttwo\t' "$log"

"$repo_dir/lib/install-plan" prepare --mode full --os macos \
    --output "$fixture/tampered.plan" >/dev/null
printf '%s\n' $'action\tfoundation.git\tcommand\trm -rf /\t' >>"$fixture/tampered.plan"
if DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/fake-adapter" INSTALL_PLAN_TEST_LOG="$log" \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/tampered.plan" \
    >/dev/null 2>"$fixture/tampered.err"; then
    echo 'Expected an action absent from the catalog to fail validation' >&2
    exit 1
fi
grep -Fq 'resolved plan action is absent from catalog' "$fixture/tampered.err"

printf 'Installation plan apply tests passed.\n'
