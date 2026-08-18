#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-install-observation.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
catalog="$fixture/catalog"
mkdir -p "$catalog/platforms"

cat >"$catalog/steps.tsv" <<'EOF'
10	dependencies	Install dependencies	on	dependencies
EOF
cat >"$catalog/groups.tsv" <<'EOF'
10	foundation	Foundation	on
20	gaming	Gaming	on
EOF
cat >"$catalog/applications.tsv" <<'EOF'
foundation.git	foundation	Git	required
gaming.steam	gaming	Steam	on
gaming.mystery	gaming	Mystery	on
gaming.unknown	gaming	Unknown	on
EOF
cat >"$catalog/platforms/macos.tsv" <<'EOF'
foundation.git	brew-formula	git
gaming.steam	brew-cask	steam
gaming.mystery	installer	mystery
gaming.unknown	installer	unknown
EOF
cat >"$catalog/removals.tsv" <<'EOF'
macos	gaming.mystery	path	~/.local/bin/mystery	
EOF
cat >"$fixture/inspect" <<'EOF'
#!/usr/bin/env bash
case "$2" in
    git|steam) printf 'present\tmanaged\t%s is registered\n' "$2" ;;
    mystery) printf 'present\tunverified\tmystery found without a receipt\n' ;;
    unknown) printf 'unknown\tunverified\tinspection failed\n' ;;
esac
EOF
chmod +x "$fixture/inspect"

DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_INSPECTOR="$fixture/inspect" \
    "$repo_dir/lib/install-plan" inspect --os macos --output "$fixture/observations.tsv"

grep -Fxq $'format\t1' "$fixture/observations.tsv"
grep -Fxq $'os\tmacos' "$fixture/observations.tsv"
grep -Fxq $'observation\tfoundation.git\tavailable\tpresent\tmanaged\trequired\tdisabled\tdisabled\tfoundation\tGit\tgit is registered' "$fixture/observations.tsv"
grep -Fxq $'observation\tgaming.steam\tavailable\tpresent\tmanaged\toptional\tenabled\tdisabled\tgaming\tSteam\tsteam is registered' "$fixture/observations.tsv"
grep -Fxq $'observation\tgaming.mystery\tavailable\tpresent\tunverified\toptional\tdisabled\tenabled\tgaming\tMystery\tmystery found without a receipt' "$fixture/observations.tsv"
grep -Fxq $'observation\tgaming.unknown\tavailable\tunknown\tunverified\toptional\tdisabled\tdisabled\tgaming\tUnknown\tinspection failed' "$fixture/observations.tsv"

mkdir -p "$fixture/bin" "$fixture/state/dotfiles/receipts/macos"
printf '#!/bin/sh\nexit 0\n' >"$fixture/bin/mystery"
chmod +x "$fixture/bin/mystery"
if command -v sha256sum >/dev/null; then digest=$(sha256sum "$fixture/bin/mystery" | awk '{print $1}'); else digest=$(shasum -a 256 "$fixture/bin/mystery" | awk '{print $1}'); fi
printf 'format\t1\napp\tgaming.mystery\ninstaller\tmystery\ntarget\t%s\nsha256\t%s\n' \
    "$fixture/bin/mystery" "$digest" >"$fixture/state/dotfiles/receipts/macos/gaming.mystery.tsv"
XDG_STATE_HOME="$fixture/state" DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_INSPECTOR="$fixture/inspect" \
    "$repo_dir/lib/install-plan" inspect --os macos --output "$fixture/receipted.tsv"
grep -Fxq $'observation\tgaming.mystery\tavailable\tpresent\tmanaged\toptional\tenabled\tenabled\tgaming\tMystery\tvalidated installation receipt for '"$fixture/bin/mystery" "$fixture/receipted.tsv"
grep -Fxq $'mechanism\tgaming.mystery\treceipt\t'"$fixture/bin/mystery"$'\tmystery' "$fixture/receipted.tsv"

printf 'Application observation and receipt contract tests passed.\n'
