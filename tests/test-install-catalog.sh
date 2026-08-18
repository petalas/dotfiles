#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-install-catalog.XXXXXX)
trap 'rm -rf "$fixture"' EXIT

for os in macos ubuntu debian arch; do
    "$repo_dir/lib/install-plan" prepare --mode full --os "$os" \
        --output "$fixture/$os.plan" >"$fixture/$os.out"
    [[ "$(grep -c $'^group\t' "$fixture/$os.plan")" == 16 ]]
    for required in foundation.bootstrap foundation.git foundation.locale languages.bun languages.node languages.rust; do
        grep -Fq $'app\t'"$required"$'\ton\trequired\t' "$fixture/$os.plan"
    done
done

# Frozen pre-migration inventories independently protect package ownership.
awk -F '\t' '$2 == "apt-package" {print $3}' "$repo_dir/catalog/platforms/debian.tsv" |
    sort -u >"$fixture/debian-packages"
cmp -s "$repo_dir/tests/fixtures/catalog/debian-packages" "$fixture/debian-packages"
awk -F '\t' '$2 == "pacman-package" {print $3}' "$repo_dir/catalog/platforms/arch.tsv" |
    sort -u >"$fixture/arch-packages"
cmp -s "$repo_dir/tests/fixtures/catalog/arch-packages" "$fixture/arch-packages"
"$repo_dir/tools/generate-brewfile" |
    awk '/^(brew|cask|tap) / {print}' | sort >"$fixture/macos-brew.entries"
cmp -s "$repo_dir/tests/fixtures/catalog/macos-brew.entries" "$fixture/macos-brew.entries"
for os in macos debian arch; do
    awk -F '\t' '$2 == "installer" || $2 == "npm-package" || $2 == "cargo-package" {print}' \
        "$repo_dir/catalog/platforms/$os.tsv" | sort >"$fixture/$os-addon-actions"
    cmp -s "$repo_dir/tests/fixtures/catalog/$os-addon-actions" "$fixture/$os-addon-actions"
done

# Representative declarations protect each adapter ownership surface.
grep -Fxq $'action\tgaming.steam\tbrew-cask\tsteam\t' "$fixture/macos.plan"
grep -Fxq $'action\tcad.bambu-studio\tbrew-cask\tbambu-studio\t' "$fixture/macos.plan"
grep -Fxq $'action\tmobile.maestro\tbrew-formula\tmobile-dev-inc/tap/maestro\ttrusted=true' "$fixture/macos.plan"
grep -Fxq $'action\tfoundation.locale\tapt-package\tlocales\t' "$fixture/debian.plan"
grep -Fxq $'action\tcli.fd\tcommand-alias\tfd:fdfind\t' "$fixture/debian.plan"
grep -Fxq $'action\tcli.bat\tcommand-alias\tbat:batcat\t' "$fixture/debian.plan"
grep -Fxq $'action\teditors.code\tinstaller\tcode\t' "$fixture/ubuntu.plan"
grep -Fxq $'action\tcontainers.docker\tpacman-package\tdocker\t' "$fixture/arch.plan"
grep -Fxq $'group\tgaming\ton\t160\tGaming & streaming\tunavailable' "$fixture/linux.plan" 2>/dev/null || \
    grep -Fxq $'group\tgaming\ton\t160\tGaming & streaming\tunavailable' "$fixture/debian.plan"

# The compatibility Brewfile is generated deterministically from the catalog.
"$repo_dir/tools/generate-brewfile" >"$fixture/Brewfile"
cmp -s "$fixture/Brewfile" "$repo_dir/Brewfile" || {
    echo "Generated Brewfile drifted" >&2
    diff -u "$repo_dir/Brewfile" "$fixture/Brewfile" >&2 || true
    exit 1
}
grep -Fxq 'brew "wix-incubator/brew/applesimutils", trusted: true' "$fixture/Brewfile"

printf 'Installation catalog parity tests passed.\n'
