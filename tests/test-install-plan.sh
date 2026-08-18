#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-install-plan.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
catalog="$fixture/catalog"
mkdir -p "$catalog/platforms"

cat >"$catalog/steps.tsv" <<'EOF'
10	dependencies	Install dependencies	on	dependencies
20	links	Link dotfiles	on	command	./link-dotfiles.sh
EOF
cat >"$catalog/groups.tsv" <<'EOF'
10	foundation	Foundation	on
20	languages	Languages & runtimes	on
30	gaming	Gaming & streaming	off
EOF
cat >"$catalog/applications.tsv" <<'EOF'
foundation.git	foundation	Git	required
languages.node	languages	Node	required	foundation.git
languages.python	languages	Python	on	foundation.git
gaming.steam	gaming	Steam	on
EOF
cat >"$catalog/platforms/macos.tsv" <<'EOF'
foundation.git	brew	payload	brew-formula	git
languages.node	brew	payload	brew-formula	node
languages.python	brew	payload	brew-formula	python@3.14
gaming.steam	brew	payload	brew-cask	steam
EOF
cp "$catalog/platforms/macos.tsv" "$catalog/platforms/ubuntu.tsv"
cp "$catalog/platforms/macos.tsv" "$catalog/platforms/debian.tsv"
cp "$catalog/platforms/macos.tsv" "$catalog/platforms/arch.tsv"

plan="$fixture/full.plan"
DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$plan" >"$fixture/full.out"

grep -Fxq $'step\tdependencies\ton\t10\tInstall dependencies' "$plan"
grep -Fxq $'group\tgaming\ton\t30\tGaming & streaming\tavailable' "$plan"
grep -Fxq $'app\tlanguages.node\ton\trequired\tlanguages\tNode' "$plan"
grep -Fxq $'action\tgaming.steam\tbrew-cask\tsteam\t' "$plan"
grep -Fq 'Install dependencies' "$fixture/full.out"
grep -Fq 'Gaming & streaming' "$fixture/full.out"
grep -Fq 'Node' "$fixture/full.out"
grep -Fq 'Steam' "$fixture/full.out"

record="$fixture/selection"
cat >"$record" <<'EOF'
format=1
step.dependencies=off
group.foundation=off
group.languages=off
app.languages.python=on
app.languages.node=off
EOF
DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare \
    --mode record --record "$record" --os macos --output "$fixture/record.plan" \
    >"$fixture/record.out"
grep -Fxq $'step\tdependencies\toff\t10\tInstall dependencies' "$fixture/record.plan"
grep -Fxq $'group\tfoundation\ton\t10\tFoundation\tavailable' "$fixture/record.plan"
grep -Fq 'Foundation group cannot be disabled' "$fixture/record.out"
grep -Fxq $'app\tlanguages.node\ton\trequired\tlanguages\tNode' "$fixture/record.plan"
grep -Fxq $'app\tlanguages.python\ton\toptional\tlanguages\tPython' "$fixture/record.plan"
grep -Fq 'required application languages.node cannot be disabled' "$fixture/record.out"

cat >"$fixture/duplicate-record" <<'EOF'
format=1
group.languages=on
group.languages=off
EOF
if DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare \
    --mode record --record "$fixture/duplicate-record" --os macos \
    --output "$fixture/duplicate-record.plan" >/dev/null 2>"$fixture/duplicate-record.err"; then
    echo "Expected duplicate record key to fail" >&2
    exit 1
fi
grep -Fq 'duplicate plan record key' "$fixture/duplicate-record.err"

cp -R "$catalog" "$fixture/order-catalog"
awk -F '\t' 'BEGIN {OFS="\t"} $2 == "gaming" {$1=20} {print}' \
    "$catalog/groups.tsv" >"$fixture/order-catalog/groups.tsv"
if DOTFILES_CATALOG_DIR="$fixture/order-catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$fixture/order.plan" >/dev/null 2>"$fixture/order.err"; then
    echo "Expected duplicate group order to fail" >&2
    exit 1
fi
grep -Fq 'duplicate group order' "$fixture/order.err"

cp -R "$catalog" "$fixture/option-catalog"
printf '%s\n' $'gaming.steam\tbrew\tpayload\tbrew-formula\tsteam\ttrusted=no' >>"$fixture/option-catalog/platforms/macos.tsv"
if DOTFILES_CATALOG_DIR="$fixture/option-catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$fixture/option.plan" >/dev/null 2>"$fixture/option.err"; then
    echo "Expected invalid adapter option to fail" >&2
    exit 1
fi
grep -Fq 'invalid option' "$fixture/option.err"

cat >>"$catalog/applications.tsv" <<'EOF'
languages.loop	languages	Loop	on	languages.loop
EOF
cat >>"$catalog/platforms/macos.tsv" <<'EOF'
languages.loop	brew	payload	brew-formula	loop
EOF
if DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$fixture/cycle.plan" \
    >"$fixture/cycle.out" 2>"$fixture/cycle.err"; then
    echo "Expected dependency cycle validation to fail" >&2
    exit 1
fi
grep -Fq 'dependency cycle' "$fixture/cycle.err"

echo "Installation plan prepare tests passed."
