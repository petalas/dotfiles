#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ghostty="$repo_dir/dot/.config/ghostty/config.ghostty"
kitty="$repo_dir/dot/.config/kitty/kitty.conf"
pi_theme="$repo_dir/dot/.pi/agent/themes/seashells.json"
omp_theme="$repo_dir/dot/.omp/agent/themes/seashells.json"
p10k="$repo_dir/dot/p10k-seashells.zsh"
profile="$repo_dir/dot/terminal/SeaShells.terminal"

fail() {
    printf 'SeaShells palette contract failed: %s\n' "$1" >&2
    exit 1
}

expect_equal() {
    local label=$1 actual=$2 expected=$3
    [[ "$actual" == "$expected" ]] || fail "$label is $actual, expected $expected"
}

ghostty_value() {
    awk -F '[[:space:]]*=[[:space:]]*' -v sought="$1" \
        '$1 == sought { value = $2 } END { print value }' "$ghostty"
}

ghostty_ansi_value() {
    awk -F '[[:space:]]*=[[:space:]]*' -v sought="$1" \
        '$1 == "palette" && $2 == sought { value = $3 } END { print value }' "$ghostty"
}

kitty_value() {
    awk -v sought="$1" '$1 == sought { value = $2 } END { print value }' "$kitty"
}

ansi=(
    0f2838 d05023 027b9b fba02f 2d6870 68d3f0 50a3b5 deb88d
    424b52 d38677 618c98 fdd29e 1abcdd bbe3ee 86abb3 fee3cd
)
expect_equal 'Ghostty background' "$(ghostty_value background)" 08131a
expect_equal 'Ghostty foreground' "$(ghostty_value foreground)" deb88d
expect_equal 'Ghostty cursor' "$(ghostty_value cursor-color)" fba02f
expect_equal 'Ghostty selection background' "$(ghostty_value selection-background)" 1e4862
expect_equal 'Ghostty selection foreground' "$(ghostty_value selection-foreground)" deb88d
expect_equal 'Kitty background' "$(kitty_value background)" '#08131a'
expect_equal 'Kitty foreground' "$(kitty_value foreground)" '#deb88d'
expect_equal 'Kitty cursor' "$(kitty_value cursor)" '#fba02f'
expect_equal 'Kitty selection background' "$(kitty_value selection_background)" '#1e4862'
expect_equal 'Kitty selection foreground' "$(kitty_value selection_foreground)" '#deb88d'
for index in "${!ansi[@]}"; do
    expect_equal "Ghostty ANSI $index" "$(ghostty_ansi_value "$index")" "${ansi[$index]}"
    expect_equal "Kitty ANSI $index" "$(kitty_value "color$index")" "#${ansi[$index]}"
done

upstream='https://github.com/odysseyalive/omarchy-seashells-theme/blob/00dca31761374d5526790dd8a10271edbc6f9ec8/omarchy/themes/seashells/colors.toml'
grep -Fxq "# $upstream" "$ghostty" || fail 'Ghostty upstream reference is missing'
grep -Fxq "# $upstream" "$kitty" || fail 'Kitty upstream reference is missing'

expected_vars='{
  "background":"#08131a","foreground":"#deb88d","cursor":"#fba02f","selection":"#1e4862",
  "black":"#0f2838","brightBlack":"#424b52","red":"#d05023","brightRed":"#d38677",
  "green":"#027b9b","brightGreen":"#618c98","yellow":"#fba02f","brightYellow":"#fdd29e",
  "blue":"#2d6870","brightBlue":"#1abcdd","magenta":"#68d3f0","brightMagenta":"#bbe3ee",
  "cyan":"#50a3b5","brightCyan":"#86abb3","white":"#deb88d","brightWhite":"#fee3cd"
}'
for theme in "$pi_theme" "$omp_theme"; do
    jq -e --argjson expected "$expected_vars" \
        '.vars == $expected and .colors.accent == "cyan" and .colors.borderAccent == "cyan"' \
        "$theme" >/dev/null || fail "$theme has a mismatched palette or accent mapping"
done

expected_allowlist='#08131a|#0f2838|#424b52|#d05023|#d38677|#027b9b|#618c98|#fba02f|#fdd29e|#2d6870|#1abcdd|#68d3f0|#bbe3ee|#50a3b5|#86abb3|#deb88d|#fee3cd'
grep -Fxq "    ($expected_allowlist)" "$p10k" || fail 'P10k literal allowlist is mismatched'
if grep -Eiq '(^|[^0-9a-f])(17384c|1d4850)($|[^0-9a-f])' \
    "$ghostty" "$kitty" "$pi_theme" "$omp_theme" "$p10k"; then
    fail 'an obsolete SeaShells color remains'
fi

if command -v python3 >/dev/null 2>&1; then
    PROFILE="$profile" python3 <<'PY'
import base64
import os
import plistlib
import xml.etree.ElementTree as ET

outer = ET.parse(os.environ["PROFILE"]).getroot().find("dict")
children = list(outer)
blobs = {
    children[index].text: base64.b64decode(children[index + 1].text)
    for index in range(0, len(children), 2)
    if children[index + 1].tag == "data"
}
def nsrgb(key):
    return plistlib.loads(blobs[key])["$objects"][1]["NSRGB"]
assert nsrgb("ANSIBlackColor") == b"0.05882352941 0.1568627451 0.2196078431\0"
assert nsrgb("ANSIBlueColor") == b"0.1764705882 0.4078431373 0.4392156863\0"
assert blobs["SelectedTextColor"] == blobs["TextColor"]
PY
fi

printf 'SeaShells palette contracts passed.\n'
