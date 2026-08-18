#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-install-removal.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
catalog="$fixture/catalog"
mkdir -p "$catalog/platforms" "$fixture/state"
cat >"$catalog/steps.tsv" <<'EOF'
10	dependencies	Install dependencies	on	dependencies
EOF
cat >"$catalog/groups.tsv" <<'EOF'
10	foundation	Foundation	on
20	tools	Tools	on
EOF
cat >"$catalog/applications.tsv" <<'EOF'
foundation.git	foundation	Git	required
tools.runtime	tools	Runtime	on
tools.client	tools	Client	on	tools.runtime
tools.loose	tools	Loose	on
EOF
cat >"$catalog/platforms/macos.tsv" <<'EOF'
foundation.git	provided	git
tools.runtime	brew-formula	runtime
tools.client	brew-formula	client
tools.loose	installer	loose
EOF
cat >"$catalog/removals.tsv" <<'EOF'
macos	tools.loose	path	~/.local/bin/loose
EOF
cat >"$fixture/observations.tsv" <<'EOF'
format	1
os	macos
observation	foundation.git	available	present	provided	required	disabled	disabled	foundation	Git	provided
observation	tools.runtime	available	present	managed	optional	enabled	disabled	tools	Runtime	registered
mechanism	tools.runtime	brew-formula	runtime
observation	tools.client	available	present	managed	optional	enabled	disabled	tools	Client	registered
mechanism	tools.client	brew-formula	client
observation	tools.loose	available	present	unverified	optional	disabled	enabled	tools	Loose	found
EOF
cat >"$fixture/blocked-selection.tsv" <<'EOF'
format	1
outcome	foundation.git	ensure
outcome	tools.runtime	remove
outcome	tools.client	leave
outcome	tools.loose	leave
EOF

DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare \
    --mode outcomes --os macos --selection "$fixture/blocked-selection.tsv" \
    --observations "$fixture/observations.tsv" --output "$fixture/blocked.plan" >/dev/null

grep -Fxq $'app\ttools.runtime\tleave\toptional\ttools\tRuntime\tpresent\tmanaged' "$fixture/blocked.plan"
grep -Fxq $'blocker\ttools.runtime\tretained-dependent\ttools.client' "$fixture/blocked.plan"

cat >"$fixture/removal-selection.tsv" <<'EOF'
format	1
outcome	foundation.git	ensure
outcome	tools.runtime	remove
outcome	tools.client	remove
outcome	tools.loose	force
EOF
DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare \
    --mode outcomes --os macos --selection "$fixture/removal-selection.tsv" \
    --observations "$fixture/observations.tsv" --output "$fixture/removal.plan" >/dev/null

grep -Fxq $'removal\ttools.runtime\texact\tbrew-formula\truntime\t' "$fixture/removal.plan"
grep -Fxq $'removal\ttools.client\texact\tbrew-formula\tclient\t' "$fixture/removal.plan"
grep -Fxq $'removal\ttools.loose\tforce\tpath\t~/.local/bin/loose\t' "$fixture/removal.plan"

cat >"$fixture/adapter" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$INSTALL_PLAN_TEST_LOG"
EOF
chmod +x "$fixture/adapter"
DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/adapter" \
DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 INSTALL_PLAN_TEST_LOG="$fixture/actions" \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/removal.plan" \
    --report "$fixture/report.tsv" >"$fixture/execute.out" 2>"$fixture/execute.err"

client_line=$(grep -nFx 'remove brew-formula client ' "$fixture/actions" | cut -d: -f1)
runtime_line=$(grep -nFx 'remove brew-formula runtime ' "$fixture/actions" | cut -d: -f1)
((client_line < runtime_line))
grep -Fxq 'force path ~/.local/bin/loose ' "$fixture/actions"
grep -Fq 'succeeded: tools.client' "$fixture/execute.out"
grep -Fq 'succeeded: tools.loose' "$fixture/execute.out"
grep -Fxq $'method\ttools.loose\tforce\tpath\t~/.local/bin/loose\tsucceeded' "$fixture/report.tsv"

sed 's#~/.local/bin/loose#/tmp/evil#' "$fixture/removal.plan" >"$fixture/tampered.plan"
if command -v sha256sum >/dev/null; then digest=$(sha256sum "$fixture/tampered.plan" | awk '{print $1}'); else digest=$(shasum -a 256 "$fixture/tampered.plan" | awk '{print $1}'); fi
printf 'format\t1\ndigest\t%s\n' "$digest" >"$fixture/tampered.approval"
if DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_ADAPTER="$fixture/adapter" \
    INSTALL_PLAN_TEST_LOG="$fixture/actions" "$repo_dir/lib/install-plan" execute --operation install \
    --plan "$fixture/tampered.plan" --approval "$fixture/tampered.approval" >/dev/null 2>"$fixture/tampered.err"; then
    echo 'Expected a removal target absent from the catalog to fail validation' >&2
    exit 1
fi
grep -Fq 'prepared removal is absent from catalog' "$fixture/tampered.err"

cat >"$catalog/platforms/ubuntu.tsv" <<'EOF'
foundation.git	provided	git
tools.runtime	apt-package	runtime
tools.client	apt-package	client
tools.loose	installer	loose
EOF
sed 's/^os\tmacos$/os\tubuntu/; s/brew-formula/apt-package/g' "$fixture/observations.tsv" >"$fixture/ubuntu-observations.tsv"
sed $'s/outcome\ttools.loose\tforce/outcome\ttools.loose\tleave/' "$fixture/removal-selection.tsv" >"$fixture/apt-selection.tsv"
DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare --mode outcomes --os ubuntu \
    --selection "$fixture/apt-selection.tsv" --observations "$fixture/ubuntu-observations.tsv" \
    --output "$fixture/apt.plan" >/dev/null
mkdir -p "$fixture/bin"
cat >"$fixture/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -s ]]; then
    printf 'Remv %s\nRemv retained-dependent\n' "${@: -1}"
    exit 0
fi
printf 'unexpected execution\n' >>"$INSTALL_PLAN_TEST_LOG"
EOF
chmod +x "$fixture/bin/apt-get"
if PATH="$fixture/bin:$PATH" INSTALL_PLAN_TEST_LOG="$fixture/apt-actions" \
    DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/apt.plan" \
    >/dev/null 2>"$fixture/apt.err"; then
    echo 'Expected an unexpected APT preview target to block removal' >&2
    exit 1
fi
grep -Fq 'Removal preview includes unexpected package: retained-dependent' "$fixture/apt.err"
[[ ! -e "$fixture/apt-actions" ]]

printf 'Dependency-safe removal tests passed.\n'
