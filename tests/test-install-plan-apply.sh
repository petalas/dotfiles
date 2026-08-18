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
grep -Fq 'succeeded: step links' "$fixture/out"
grep -Fq 'failed: step dependencies' "$fixture/err"

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

# npm and Cargo batches must establish their declared toolchain prerequisites
# before invoking either package manager. Direct toolchain installers otherwise
# run later in the per-application phase and the batch sees the system binary.
cat >"$fixture/toolchain-batch-plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	languages.node	on	required	languages	Node and npm
app	languages.rust	on	required	languages	Rust and Cargo
app	ai.cli	on	optional	ai	AI CLI
app	development.tool	on	optional	development	Development tool
dependency	ai.cli	languages.node
dependency	development.tool	languages.rust
action	languages.node	installer	node
action	languages.rust	installer	rust
action	ai.cli	npm-package	@example/cli
action	development.tool	cargo-package	example-tool
EOF
: >"$log"
DOTFILES_INSTALL_PLAN_BATCH_ADAPTER="$fixture/fake-batch" \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/fake-adapter" INSTALL_PLAN_TEST_LOG="$log" \
    DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/toolchain-batch-plan" \
    >"$fixture/toolchain-batch.out" 2>"$fixture/toolchain-batch.err"
[[ "$(sed -n '1p' "$log")" == 'install installer node ' ]]
[[ "$(sed -n '2p' "$log")" == 'batch install npm-package' ]]
grep -Fxq $'ai.cli\t@example/cli\t' "$log"
[[ "$(sed -n '4p' "$log")" == 'install installer rust ' ]]
[[ "$(sed -n '5p' "$log")" == 'batch install cargo-package' ]]
grep -Fxq $'development.tool\texample-tool\t' "$log"

# A successful direct installer may claim custody when it demonstrably changes
# a pre-existing command. A no-op over an unreceipted command still may not.
mkdir -p "$fixture/receipt-bin"
cat >"$fixture/receipt-bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf 'old\n'
EOF
chmod +x "$fixture/receipt-bin/herdr"
cat >"$fixture/receipt-plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	ai.herdr	on	optional	ai	Herdr
action	ai.herdr	installer	herdr
EOF
cat >"$fixture/receipt-adapter" <<'EOF'
#!/usr/bin/env bash
if [[ "$3" == herdr && "$RECEIPT_ADAPTER_MODE" == update ]]; then
    cat >"$RECEIPT_BIN/herdr" <<'SCRIPT'
#!/usr/bin/env bash
printf 'new\n'
SCRIPT
    chmod +x "$RECEIPT_BIN/herdr"
fi
EOF
chmod +x "$fixture/receipt-adapter"
receipt="$fixture/state/dotfiles/receipts/debian/ai.herdr.tsv"
PATH="$fixture/receipt-bin:/usr/bin:/bin" XDG_STATE_HOME="$fixture/state" \
RECEIPT_BIN="$fixture/receipt-bin" RECEIPT_ADAPTER_MODE=update \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/receipt-adapter" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/receipt-plan" >/dev/null
grep -Fxq $'target\t'"$fixture/receipt-bin/herdr" "$receipt"
rm -f "$receipt"
PATH="$fixture/receipt-bin:/usr/bin:/bin" XDG_STATE_HOME="$fixture/state" \
RECEIPT_BIN="$fixture/receipt-bin" RECEIPT_ADAPTER_MODE=noop \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/receipt-adapter" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/receipt-plan" >/dev/null
[[ ! -e "$receipt" ]]

# Receipt metadata for packaged desktop applications must come from the package
# database. Executing the GUI target can launch the application, and truncating
# its output can leave Electron writing to a closed pipe.
mkdir -p "$fixture/gui-receipt-bin"
cat >"$fixture/gui-receipt-bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == '-W -f=${Version} bitwarden' ]] || exit 1
printf '2026.7.0'
EOF
chmod +x "$fixture/gui-receipt-bin/dpkg-query"
cat >"$fixture/gui-receipt-plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	productivity.bitwarden	on	optional	productivity	Bitwarden
action	productivity.bitwarden	installer	bitwarden
EOF
cat >"$fixture/gui-receipt-adapter" <<'EOF'
#!/usr/bin/env bash
cat >"$GUI_RECEIPT_BIN/bitwarden" <<'SCRIPT'
#!/usr/bin/env bash
printf 'invoked %s\n' "$*" >"$BITWARDEN_EXECUTION_MARKER"
printf 'X11 available: true\n'
SCRIPT
chmod +x "$GUI_RECEIPT_BIN/bitwarden"
EOF
chmod +x "$fixture/gui-receipt-adapter"
gui_receipt="$fixture/gui-state/dotfiles/receipts/debian/productivity.bitwarden.tsv"
PATH="$fixture/gui-receipt-bin:/usr/bin:/bin" XDG_STATE_HOME="$fixture/gui-state" \
GUI_RECEIPT_BIN="$fixture/gui-receipt-bin" BITWARDEN_EXECUTION_MARKER="$fixture/bitwarden-executed" \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/gui-receipt-adapter" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/gui-receipt-plan" >/dev/null
[[ ! -e "$fixture/bitwarden-executed" ]]
grep -Fxq $'version\t2026.7.0' "$gui_receipt"

# Post-operation inspection must translate a prepared-run index back to the
# full catalog. An unavailable catalog entry is omitted from the prepared run.
alignment_catalog="$fixture/alignment-catalog"
mkdir -p "$alignment_catalog/platforms"
printf '10\tdependencies\tInstall dependencies\ton\tdependencies\t\n' >"$alignment_catalog/steps.tsv"
printf '10\ttest\tTest\ton\n' >"$alignment_catalog/groups.tsv"
printf '%s\n' \
    $'test.one\ttest\tOne\ton\t' \
    $'test.unavailable\ttest\tUnavailable\ton\t' \
    $'test.two\ttest\tTwo\ton\t' >"$alignment_catalog/applications.tsv"
printf '%s\n' \
    $'test.one\tprovided\tpayload\tprovided\tone\t' \
    $'test.two\tprovided\tpayload\tprovided\ttwo\t' >"$alignment_catalog/platforms/debian.tsv"
: >"$alignment_catalog/removals.tsv"
printf '%s\n' \
    $'format\t1' \
    $'os\tdebian' \
    $'step\tdependencies\ton\t10\tInstall dependencies' \
    $'app\ttest.one\ton\toptional\ttest\tOne' \
    $'action\ttest.one\tprovided\tone\t' \
    $'app\ttest.two\ton\toptional\ttest\tTwo' \
    $'action\ttest.two\tprovided\ttwo\t' >"$fixture/alignment-plan"
DOTFILES_CATALOG_DIR="$alignment_catalog" "$repo_dir/lib/install-plan" apply --operation install \
    --plan "$fixture/alignment-plan" --report "$fixture/alignment-report" \
    >"$fixture/alignment.out" 2>"$fixture/alignment.err"
grep -Fxq $'post-observation\ttest.one\tpresent\tprovided' "$fixture/alignment-report"
grep -Fxq $'post-observation\ttest.two\tpresent\tprovided' "$fixture/alignment-report"
grep -Fxq $'result\ttest.two\tsucceeded' "$fixture/alignment-report"

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
