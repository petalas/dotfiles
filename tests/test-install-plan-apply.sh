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

# Reconciliation installs only missing npm packages and only outdated Cargo
# packages, avoiding no-op reinstalls while still updating tracked crates.
package_bin="$fixture/package-bin"
mkdir -p "$package_bin"
cat >"$package_bin/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$package_bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >>"$PACKAGE_BATCH_LOG"
if [[ "$1" == list ]]; then
    [[ "${*: -1}" == @example/present ]]
fi
EOF
cat >"$package_bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo %s\n' "$*" >>"$PACKAGE_BATCH_LOG"
case "$*" in
    'install --list')
        printf 'current-tool v1.0.0:\n    current-tool\noutdated-tool v1.0.0:\n    outdated-tool\n'
        ;;
    'info current-tool') printf 'version: 1.0.0\n' ;;
    'info outdated-tool') printf 'version: 1.1.0\n' ;;
esac
EOF
chmod +x "$package_bin/node" "$package_bin/npm" "$package_bin/cargo"
package_catalog="$fixture/package-catalog"
mkdir -p "$package_catalog/platforms"
printf '10\tdependencies\tInstall dependencies\ton\tdependencies\n' >"$package_catalog/steps.tsv"
printf '%s\n' $'10\tlanguages\tLanguages\ton' $'20\tai\tAI\ton' \
    $'30\tdevelopment\tDevelopment\ton' >"$package_catalog/groups.tsv"
printf '%s\n' \
    $'languages.node\tlanguages\tNode\trequired' \
    $'languages.rust\tlanguages\tRust\trequired' \
    $'ai.present\tai\tPresent npm package\ton\tlanguages.node' \
    $'ai.missing\tai\tMissing npm package\ton\tlanguages.node' \
    $'development.current\tdevelopment\tCurrent Cargo package\ton\tlanguages.rust' \
    $'development.outdated\tdevelopment\tOutdated Cargo package\ton\tlanguages.rust' \
    >"$package_catalog/applications.tsv"
printf '%s\n' \
    $'languages.node\tprovided\tpayload\tprovided\tnode' \
    $'languages.rust\tprovided\tpayload\tprovided\tcargo' \
    $'ai.present\tnpm\tpayload\tnpm-package\t@example/present' \
    $'ai.missing\tnpm\tpayload\tnpm-package\t@example/missing' \
    $'development.current\tcargo\tpayload\tcargo-package\tcurrent-tool' \
    $'development.outdated\tcargo\tpayload\tcargo-package\toutdated-tool' \
    >"$package_catalog/platforms/debian.tsv"
: >"$package_catalog/removals.tsv"
cat >"$fixture/package-reconcile-plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	languages.node	on	required	languages	Node
app	languages.rust	on	required	languages	Rust
app	ai.present	on	optional	ai	Present npm package
app	ai.missing	on	optional	ai	Missing npm package
app	development.current	on	optional	development	Current Cargo package
app	development.outdated	on	optional	development	Outdated Cargo package
dependency	ai.present	languages.node
dependency	ai.missing	languages.node
dependency	development.current	languages.rust
dependency	development.outdated	languages.rust
action	languages.node	provided	node
action	languages.rust	provided	cargo
action	ai.present	npm-package	@example/present
action	ai.missing	npm-package	@example/missing
action	development.current	cargo-package	current-tool
action	development.outdated	cargo-package	outdated-tool
EOF
package_log="$fixture/package-batch.log"
: >"$package_log"
PATH="$package_bin:/usr/bin:/bin" PACKAGE_BATCH_LOG="$package_log" \
DOTFILES_CATALOG_DIR="$package_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation reconcile --plan "$fixture/package-reconcile-plan" \
    >"$fixture/package-reconcile.out" 2>"$fixture/package-reconcile.err"
grep -Fxq 'npm install --global @example/missing' "$package_log"
if grep -Fq 'npm install --global @example/present' "$package_log"; then
    echo 'Reconciliation reinstalled a present npm package' >&2
    exit 1
fi
grep -Fxq 'cargo install --locked outdated-tool' "$package_log"
if grep -Fq 'cargo install --locked current-tool' "$package_log"; then
    echo 'Reconciliation reinstalled a current Cargo package' >&2
    exit 1
fi
: >"$package_log"
PATH="$package_bin:/usr/bin:/bin" PACKAGE_BATCH_LOG="$package_log" \
DOTFILES_CATALOG_DIR="$package_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/package-reconcile-plan" \
    >"$fixture/package-install.out" 2>"$fixture/package-install.err"
grep -Fxq 'npm install --global @example/present @example/missing' "$package_log"
grep -Fxq 'cargo install --locked current-tool outdated-tool' "$package_log"

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

# Once an installation plan receives an interrupt, it must not dispatch another
# dependency action after the active adapter settles.
cat >"$fixture/interrupt-plan" <<'EOF'
format	1
os	debian
step	dependencies	on	10	Install dependencies
app	interrupt.one	on	optional	cli	Interrupt one
app	interrupt.two	on	optional	cli	Interrupt two
action	interrupt.one	installer	interrupt-one
action	interrupt.two	installer	interrupt-two
EOF
cat >"$fixture/interrupt-adapter" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$3" >>"$INSTALL_PLAN_TEST_LOG"
if [[ "$3" == interrupt-one ]]; then
    : >"$INTERRUPT_READY"
    sleep 1
fi
EOF
chmod +x "$fixture/interrupt-adapter"
: >"$log"
INSTALL_PLAN_TEST_LOG="$log" INTERRUPT_READY="$fixture/interrupt-ready" \
DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/interrupt-adapter" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" apply --operation install --plan "$fixture/interrupt-plan" \
    >"$fixture/interrupt.out" 2>"$fixture/interrupt.err" &
interrupt_pid=$!
interrupt_wait_attempts=0
while [[ ! -e "$fixture/interrupt-ready" ]]; do
    if ! kill -0 "$interrupt_pid" 2>/dev/null; then
        wait "$interrupt_pid" || true
        echo 'Installation plan exited before the interrupt adapter started' >&2
        exit 1
    fi
    if ((interrupt_wait_attempts >= 500)); then
        kill -TERM "$interrupt_pid" 2>/dev/null || true
        wait "$interrupt_pid" || true
        echo 'Timed out waiting for the interrupt adapter to start' >&2
        exit 1
    fi
    sleep 0.01
    interrupt_wait_attempts=$((interrupt_wait_attempts + 1))
done
kill -TERM "$interrupt_pid"
if wait "$interrupt_pid"; then
    echo 'Expected interrupted installation plan to fail' >&2
    exit 1
else
    interrupt_status=$?
fi
[[ "$interrupt_status" == 130 ]]
grep -Fxq 'interrupt-one' "$log"
if grep -Fxq 'interrupt-two' "$log"; then
    echo 'Installation plan dispatched another dependency after interruption' >&2
    exit 1
fi
grep -Fq 'Installation interrupted.' "$fixture/interrupt.err"

printf 'Installation plan apply tests passed.\n'
