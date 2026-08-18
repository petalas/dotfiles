#!/usr/bin/env bash
# Destructive only inside disposable CI runners/containers provisioned by adapter-smoke.yml.
set -euo pipefail

if (($# != 3)); then echo "usage: $0 OS ADAPTER PACKAGE" >&2; exit 2; fi
os=$1 adapter=$2 package=$3
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-live-removal.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
catalog="$fixture/catalog"
mkdir -p "$catalog/platforms"
cat >"$catalog/steps.tsv" <<'EOF'
10	dependencies	Dependencies	on	dependencies
EOF
cat >"$catalog/groups.tsv" <<'EOF'
10	tools	Tools	on
EOF
printf 'tools.smoke\ttools\tAdapter smoke package\ton\n' >"$catalog/applications.tsv"
printf 'tools.smoke\t%s\tpayload\t%s\t%s\n' "${adapter%%-*}" "$adapter" "$package" >"$catalog/platforms/$os.tsv"
printf '%s\ttools.smoke\t%s\t%s\n' "$os" "$adapter" "$package" >"$catalog/removals.tsv"
DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" inspect --os "$os" --output "$fixture/observations"
grep -Fq $'observation\ttools.smoke\tavailable\tpresent\tmanaged' "$fixture/observations"
cat >"$fixture/selection" <<'EOF'
format	1
outcome	tools.smoke	remove
EOF
DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare --mode outcomes --os "$os" \
    --selection "$fixture/selection" --observations "$fixture/observations" --output "$fixture/plan" >/dev/null
if command -v sha256sum >/dev/null 2>&1; then digest=$(sha256sum "$fixture/plan" | awk '{print $1}'); else digest=$(shasum -a 256 "$fixture/plan" | awk '{print $1}'); fi
printf 'format\t1\ndigest\t%s\n' "$digest" >"$fixture/approval"
DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/plan" \
    --approval "$fixture/approval" --report "$fixture/report" >/dev/null
grep -Fq $'post-observation\ttools.smoke\tabsent\t' "$fixture/report" || {
    cat "$fixture/report" >&2
    exit 1
}
printf 'Live %s removal adapter smoke passed for %s.\n' "$adapter" "$package"
