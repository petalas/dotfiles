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
gaming.unavailable	gaming	Unavailable	on
EOF
cat >"$catalog/platforms/macos.tsv" <<'EOF'
foundation.git	brew	payload	brew-formula	git
gaming.steam	brew	payload	brew-cask	steam
gaming.mystery	direct	payload	installer	mystery
gaming.unknown	direct	payload	installer	unknown
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
cat >"$fixture/inspect-version" <<'EOF'
#!/usr/bin/env bash
case "$2" in
    git) printf '2.43.0\t2.45.1\tupdate\n' ;;
    steam) printf '1.0\t1.0\tcurrent\n' ;;
    mystery) printf '1.0\t-\tunknown\n' ;;
    *) printf -- '-\t-\tunknown\n' ;;
esac
EOF
chmod +x "$fixture/inspect-version"

DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_INSPECTOR="$fixture/inspect" \
    DOTFILES_INSTALL_PLAN_VERSION_INSPECTOR="$fixture/inspect-version" \
    "$repo_dir/lib/install-plan" inspect --os macos --output "$fixture/observations.tsv"

grep -Fxq $'format\t1' "$fixture/observations.tsv"
grep -Fxq $'os\tmacos' "$fixture/observations.tsv"
grep -Fxq $'observation\tfoundation.git\tavailable\tpresent\tmanaged\trequired\tdisabled\tdisabled\tfoundation\tGit (2.43.0 -> 2.45.1)\tgit is registered' "$fixture/observations.tsv"
grep -Fxq $'observation\tgaming.steam\tavailable\tpresent\tmanaged\toptional\tenabled\tdisabled\tgaming\tSteam (1.0)\tsteam is registered' "$fixture/observations.tsv"
grep -Fxq $'observation\tgaming.mystery\tavailable\tpresent\tunverified\toptional\tdisabled\tenabled\tgaming\tMystery (1.0)\tmystery found without a receipt' "$fixture/observations.tsv"
grep -Fxq $'observation\tgaming.unknown\tavailable\tunknown\tunverified\toptional\tdisabled\tdisabled\tgaming\tUnknown\tinspection failed' "$fixture/observations.tsv"
grep -Fxq $'observation\tgaming.unavailable\tunavailable\tunknown\tunverified\toptional\tdisabled\tdisabled\tgaming\tUnavailable\tno provider on macos' "$fixture/observations.tsv"

mkdir -p "$fixture/bin" "$fixture/state/dotfiles/receipts/macos"
printf '#!/bin/sh\nexit 0\n' >"$fixture/bin/mystery"
chmod +x "$fixture/bin/mystery"
if command -v sha256sum >/dev/null; then digest=$(sha256sum "$fixture/bin/mystery" | awk '{print $1}'); else digest=$(shasum -a 256 "$fixture/bin/mystery" | awk '{print $1}'); fi
printf 'format\t1\napp\tgaming.mystery\ninstaller\tmystery\nversion\t1.0\ntarget\t%s\nsha256\t%s\neffect\tcatalog-installer\n' \
    "$fixture/bin/mystery" "$digest" >"$fixture/state/dotfiles/receipts/macos/gaming.mystery.tsv"
XDG_STATE_HOME="$fixture/state" DOTFILES_CATALOG_DIR="$catalog" DOTFILES_INSTALL_PLAN_INSPECTOR="$fixture/inspect" \
    DOTFILES_INSTALL_PLAN_VERSION_INSPECTOR="$fixture/inspect-version" \
    "$repo_dir/lib/install-plan" inspect --os macos --output "$fixture/receipted.tsv"
grep -Fxq $'observation\tgaming.mystery\tavailable\tpresent\tmanaged\toptional\tenabled\tenabled\tgaming\tMystery (1.0)\tvalidated installation receipt for '"$fixture/bin/mystery" "$fixture/receipted.tsv"
grep -Fxq $'mechanism\tgaming.mystery\treceipt\t'"$fixture/bin/mystery"$'\tmystery' "$fixture/receipted.tsv"

# Real package-manager inspection snapshots installed and candidate versions once.
cp "$catalog/platforms/macos.tsv" "$catalog/platforms/debian.tsv"
printf 'foundation.git\tapt\tpayload\tapt-package\tgit\n' >"$catalog/platforms/debian.tsv"
mkdir -p "$fixture/package-bin"
cat >"$fixture/package-bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
printf 'dpkg-query\n' >>"$VERSION_COMMAND_LOG"
case "$*" in
    *Status-Abbrev*git) printf 'ii  \n' ;;
    *) printf 'git\t2.43.0\n' ;;
esac
EOF
cat >"$fixture/package-bin/apt" <<'EOF'
#!/usr/bin/env bash
printf 'apt\n' >>"$VERSION_COMMAND_LOG"
printf 'Listing...\ngit/stable 2.45.1 amd64 [upgradable from: 2.43.0]\n'
EOF
chmod +x "$fixture/package-bin/dpkg-query" "$fixture/package-bin/apt"
: >"$fixture/version-command.log"
VERSION_COMMAND_LOG="$fixture/version-command.log" PATH="$fixture/package-bin:$PATH" \
    DOTFILES_CATALOG_DIR="$catalog" "$repo_dir/lib/install-plan" \
    inspect --os debian --output "$fixture/package-observations.tsv"
grep -Fxq $'observation\tfoundation.git\tavailable\tpresent\tmanaged\trequired\tdisabled\tdisabled\tfoundation\tGit (2.43.0 -> 2.45.1)\tgit is registered by dpkg' \
    "$fixture/package-observations.tsv"
[[ $(grep -c '^apt$' "$fixture/version-command.log") == 1 ]]
[[ $(grep -c '^dpkg-query$' "$fixture/version-command.log") == 1 ]]

# Homebrew observations match tap-qualified catalog identities against the
# canonical full names reported by Homebrew, not only their short rack names.
brew_catalog="$fixture/brew-catalog"
mkdir -p "$brew_catalog/platforms" "$fixture/brew-bin"
cat >"$brew_catalog/steps.tsv" <<'EOF'
10	dependencies	Install dependencies	on	dependencies
EOF
cat >"$brew_catalog/groups.tsv" <<'EOF'
10	mobile	Mobile	on
EOF
cat >"$brew_catalog/applications.tsv" <<'EOF'
mobile.applesimutils	mobile	Apple simulator utilities	on
mobile.shared-cask	mobile	Shared-name cask	on
EOF
cat >"$brew_catalog/platforms/macos.tsv" <<'EOF'
mobile.applesimutils	brew	payload	brew-formula	wix-incubator/brew/applesimutils	trusted=true
mobile.shared-cask	brew	payload	brew-cask	applesimutils
EOF
: >"$brew_catalog/removals.tsv"
cat >"$fixture/brew-bin/brew" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    'list --formula --versions') printf 'applesimutils 0.9.12\n' ;;
    'list --cask --versions') printf 'applesimutils 9.1\n' ;;
    'outdated --formula --verbose'|'outdated --cask --verbose') : ;;
    'info --json=v2 --installed'|'info --json=v2 wix-incubator/brew/applesimutils') cat <<'JSON'
{
  "formulae": [
    {
      "name": "applesimutils",
      "full_name": "wix-incubator/brew/applesimutils",
      "installed": [{"version": "0.9.12"}]
    }
  ],
  "casks": [
    {
      "token": "applesimutils",
      "full_token": "applesimutils",
      "installed": "9.1"
    }
  ]
}
JSON
        ;;
    'list --formula applesimutils'|'list --cask applesimutils') : ;;
    *) printf 'unexpected brew command: %s\n' "$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$fixture/brew-bin/brew"
PATH="$fixture/brew-bin:$PATH" DOTFILES_CATALOG_DIR="$brew_catalog" \
    "$repo_dir/lib/install-plan" inspect --os macos --output "$fixture/brew-observations.tsv"
grep -Fxq $'observation\tmobile.applesimutils\tavailable\tpresent\tmanaged\toptional\tenabled\tdisabled\tmobile\tApple simulator utilities (0.9.12)\twix-incubator/brew/applesimutils is registered by Homebrew' \
    "$fixture/brew-observations.tsv"
grep -Fxq $'observation\tmobile.shared-cask\tavailable\tpresent\tmanaged\toptional\tenabled\tdisabled\tmobile\tShared-name cask (9.1)\tapplesimutils is registered by Homebrew' \
    "$fixture/brew-observations.tsv"

# Reconciliation uses the same identity rule for its post-operation check.
cat >"$fixture/brew-batch" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/brew-batch"
XDG_STATE_HOME="$fixture/brew-state" DOTFILES_CATALOG_DIR="$brew_catalog" \
    "$repo_dir/lib/install-plan" prepare --mode defaults --os macos --output "$fixture/brew-plan.tsv" \
    >"$fixture/brew-prepare.out"
PATH="$fixture/brew-bin:$PATH" XDG_STATE_HOME="$fixture/brew-state" DOTFILES_CATALOG_DIR="$brew_catalog" \
    DOTFILES_INSTALL_PLAN_BATCH_ADAPTER="$fixture/brew-batch" \
    "$repo_dir/lib/install-plan" apply --operation reconcile --plan "$fixture/brew-plan.tsv" \
    >"$fixture/brew-apply.out" 2>"$fixture/brew-apply.err"
grep -Fxq 'succeeded: mobile.applesimutils' "$fixture/brew-apply.out"
grep -Fxq 'succeeded: mobile.shared-cask' "$fixture/brew-apply.out"

printf 'Application observation, version, update, and receipt contract tests passed.\n'
