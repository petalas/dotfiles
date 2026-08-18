#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-install-selector.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
catalog="$fixture/catalog"
mkdir -p "$catalog/platforms" "$fixture/state"
cat >"$catalog/steps.tsv" <<'EOF'
10	dependencies	Install dependencies	on	dependencies
EOF
cat >"$catalog/groups.tsv" <<'EOF'
10	foundation	Foundation	on
20	languages	Languages & runtimes	on
30	gaming	Gaming & streaming	on
EOF
cat >"$catalog/applications.tsv" <<'EOF'
foundation.git	foundation	Git	required
languages.node	languages	Node	required	foundation.git
languages.python	languages	Python	on	foundation.git
gaming.steam	gaming	Steam	on
EOF
cat >"$catalog/platforms/macos.tsv" <<'EOF'
foundation.git	provided	git
languages.node	brew-formula	node
languages.python	brew-formula	python
gaming.steam	brew-cask	steam
EOF

cat >"$fixture/select" <<'EOF'
#!/usr/bin/env bash
input=$2
output=$3
awk '{ if ($0 == "group.gaming=on") print "group.gaming=off"; else print }' "$input" >"$output"
printf '%s\n' 'app.languages.node=off' >>"$output"
EOF
chmod +x "$fixture/select"

DOTFILES_CATALOG_DIR="$catalog" XDG_STATE_HOME="$fixture/state" \
DOTFILES_INSTALL_PLAN_SELECTOR="$fixture/select" \
    "$repo_dir/lib/install-plan" prepare --mode visual --os macos \
    --output "$fixture/visual.plan" >"$fixture/visual.out"
record="$fixture/state/dotfiles/installation-plan"
[[ -f "$record" ]]
grep -Fxq 'group.gaming=off' "$record"
grep -Fxq $'app\tlanguages.node\ton\trequired\tlanguages\tNode' "$fixture/visual.plan"
grep -Fxq $'app\tgaming.steam\toff\toptional\tgaming\tSteam' "$fixture/visual.plan"

cat >"$fixture/cancel" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$fixture/cancel"
cp "$record" "$fixture/before"
if DOTFILES_CATALOG_DIR="$catalog" XDG_STATE_HOME="$fixture/state" \
    DOTFILES_INSTALL_PLAN_SELECTOR="$fixture/cancel" \
    "$repo_dir/lib/install-plan" prepare --mode visual --os macos \
    --output "$fixture/cancel.plan" >/dev/null 2>&1; then
    echo "Expected selector cancellation to stop preparation" >&2
    exit 1
fi
cmp -s "$fixture/before" "$record"

printf 'not a record\n' >"$record"
DOTFILES_CATALOG_DIR="$catalog" XDG_STATE_HOME="$fixture/state" \
    "$repo_dir/lib/install-plan" prepare --mode defaults --os macos \
    --output "$fixture/fallback.plan" >"$fixture/fallback.out"
grep -Fq 'default plan record is invalid' "$fixture/fallback.out"
grep -Fxq $'app\tgaming.steam\ton\toptional\tgaming\tSteam' "$fixture/fallback.plan"
if DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" prepare \
    --mode record --record "$record" --os macos --output "$fixture/invalid.plan" \
    >/dev/null 2>"$fixture/invalid.err"; then
    echo 'Expected malformed explicit record to fail' >&2
    exit 1
fi

if DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_TTY="$fixture/missing-tty" \
    "$repo_dir/lib/install-plan" prepare --mode visual --os macos \
    --output "$fixture/no-tty.plan" >/dev/null 2>"$fixture/no-tty.err"; then
    echo 'Expected visual mode without a TTY to fail' >&2
    exit 1
fi
grep -Fq 'use --unattended' "$fixture/no-tty.err"

printf 'Installation selector persistence tests passed.\n'
