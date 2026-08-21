#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

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
    grep -Fxq $'step\tai-skills\ton\t15\tInstall AI skills' "$fixture/$os.plan"
    grep -Fxq $'step-action\tai-skills\tinstaller\tai_skills\t' "$fixture/$os.plan"
    grep -Fxq $'action\tlanguages.node\tinstaller\tnode\t' "$fixture/$os.plan"
    grep -Fxq $'action\tlanguages.rust\tinstaller\trust\t' "$fixture/$os.plan"
    for sdkman_candidate in java gradle kotlin maven; do
        grep -Fxq $'action\tlanguages.'"$sdkman_candidate"$'\tinstaller\t'"$sdkman_candidate"$'\t' "$fixture/$os.plan"
    done
    if grep -Eq $'^action\tlanguages\.(node|rust|java|gradle|kotlin|maven)\t(apt-package|pacman-package|brew-formula)\t' "$fixture/$os.plan"; then
        echo "Native package unexpectedly owns a managed toolchain on $os." >&2
        exit 1
    fi
done

for os in macos ubuntu debian; do
    grep -Fxq "$os"$'\tcli.yazi\tpath\t~/.local/bin/ya' "$repo_dir/catalog/removals.tsv"
    grep -Fxq "$os"$'\tcli.yazi\tpath\t~/.local/bin/yazi' "$repo_dir/catalog/removals.tsv"
    grep -Fxq "$os"$'\tcli.yazi\tpayload-tree\t~/.local/share/yazi-release' "$repo_dir/catalog/removals.tsv"
done
for os in macos ubuntu debian arch; do
    for sdkman_candidate in java gradle kotlin maven; do
        grep -Fxq "$os"$'\tlanguages.'"$sdkman_candidate"$'\tpayload-tree\t~/.sdkman/candidates/'"$sdkman_candidate" \
            "$repo_dir/catalog/removals.tsv"
    done
done
for os in ubuntu debian; do
    grep -Fxq "$os"$'\tlanguages.uv\tpath\t~/.local/bin/uv' "$repo_dir/catalog/removals.tsv"
    grep -Fxq "$os"$'\tlanguages.uv\tpath\t~/.local/bin/uvx' "$repo_dir/catalog/removals.tsv"
    grep -Fxq "$os"$'\teditors.zed\tpath\t~/.local/bin/zed' "$repo_dir/catalog/removals.tsv"
    grep -Fxq "$os"$'\teditors.zed\tpayload-tree\t~/.local/zed.app' "$repo_dir/catalog/removals.tsv"
done
if grep -Fq $'cli.yazi\tcargo-package\tyazi-build' "$repo_dir/catalog/removals.tsv"; then
    echo "The obsolete yazi-build meta-package still owns Yazi cleanup." >&2
    exit 1
fi

# Frozen pre-migration inventories independently protect package ownership.
awk -F '\t' '$4 == "apt-package" {print $5}' "$repo_dir/catalog/platforms/debian.tsv" |
    sort -u >"$fixture/debian-packages"
cmp -s "$repo_dir/tests/fixtures/catalog/debian-packages" "$fixture/debian-packages"
awk -F '\t' '$4 == "pacman-package" {print $5}' "$repo_dir/catalog/platforms/arch.tsv" |
    sort -u >"$fixture/arch-packages"
cmp -s "$repo_dir/tests/fixtures/catalog/arch-packages" "$fixture/arch-packages"
"$repo_dir/tools/generate-brewfile" |
    awk '/^(brew|cask|tap) / {print}' | sort >"$fixture/macos-brew.entries"
cmp -s "$repo_dir/tests/fixtures/catalog/macos-brew.entries" "$fixture/macos-brew.entries"
for os in macos debian arch; do
    awk -F '\t' '$4 == "installer" || $4 == "npm-package" || $4 == "cargo-package" {print}' \
        "$repo_dir/catalog/platforms/$os.tsv" | sort >"$fixture/$os-addon-actions"
    cmp -s "$repo_dir/tests/fixtures/catalog/$os-addon-actions" "$fixture/$os-addon-actions"
done

# Representative declarations protect each adapter ownership surface.
grep -Fxq $'action\tterminal.zsh\tprovided\tzsh\t' "$fixture/macos.plan"
grep -Fxq $'action\tcli.ripgrep\tcargo-package\tripgrep\tmissing-only' "$fixture/macos.plan"
grep -Fxq $'action\tgaming.steam\tbrew-cask\tsteam\t' "$fixture/macos.plan"
grep -Fxq $'action\tcad.bambu-studio\tbrew-cask\tbambu-studio\t' "$fixture/macos.plan"
grep -Fxq $'action\tmobile.maestro\tbrew-formula\tmobile-dev-inc/tap/maestro\ttrusted=true' "$fixture/macos.plan"
grep -Fxq $'dependency\tmobile.maestro\tmobile.java17' "$fixture/macos.plan"
grep -Fxq $'action\tfoundation.locale\tapt-package\tlocales\t' "$fixture/debian.plan"
grep -Fxq $'action\tcli.fd\tcommand-alias\tfd:fdfind\t' "$fixture/debian.plan"
grep -Fxq $'action\tcli.bat\tcommand-alias\tbat:batcat\t' "$fixture/debian.plan"
for declaration in \
    $'cli.bind\tapt-package\tbind9-dnsutils' \
    $'cli.fastfetch\tapt-package\tfastfetch' \
    $'cli.mtr\tapt-package\tmtr-tiny' \
    $'cli.sevenzip\tapt-package\t7zip' \
    $'cli.watch\tapt-package\tprocps' \
    $'development.glab\tapt-package\tglab' \
    $'development.git-delta\tapt-package\tgit-delta' \
    $'development.hyperfine\tapt-package\thyperfine' \
    $'languages.elixir\tapt-package\telixir' \
    $'languages.luarocks\tapt-package\tluarocks' \
    $'productivity.syncthing\tapt-package\tsyncthing' \
    $'media.poppler\tapt-package\tpoppler-utils' \
    $'media.yt-dlp\tapt-package\tyt-dlp' \
    $'creative.gimp\tapt-package\tgimp' \
    $'creative.qbittorrent\tapt-package\tqbittorrent' \
    $'creative.vlc\tapt-package\tvlc' \
    $'cad.openscad\tapt-package\topenscad'; do
    grep -Fxq $'action\t'"$declaration"$'\t' "$fixture/debian.plan"
done
grep -Fxq $'action\tcli.bottom\tcargo-package\tbottom\tmissing-only' "$fixture/debian.plan"
grep -Fxq $'action\tcli.dust\tcargo-package\tdu-dust\tmissing-only' "$fixture/debian.plan"
grep -Fxq $'dependency\tcli.bottom\tlanguages.rust' "$fixture/debian.plan"
grep -Fxq $'dependency\tcli.dust\tlanguages.rust' "$fixture/debian.plan"
grep -Fxq $'action\teditors.code\tinstaller\tcode\t' "$fixture/ubuntu.plan"
for os in ubuntu debian; do
    grep -Fxq $'action\tlanguages.uv\tinstaller\tuv\t' "$fixture/$os.plan"
    grep -Fxq $'dependency\tlanguages.uv\tlanguages.python' "$fixture/$os.plan"
    grep -Fxq $'action\teditors.zed\tinstaller\tzed\t' "$fixture/$os.plan"
done
for os in macos ubuntu debian arch; do
    grep -Fxq $'action\teditors.neovim\tinstaller\tneovim\t' "$fixture/$os.plan"
    if grep -Eq $'^action\teditors\.neovim\t(apt-package|pacman-package|brew-formula)\t' "$fixture/$os.plan"; then
        echo "Native package unexpectedly owns Neovim on $os." >&2
        exit 1
    fi
done
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
