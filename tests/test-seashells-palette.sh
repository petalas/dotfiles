#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ghostty_config="$repo_dir/dot/.config/ghostty/config.ghostty"
ghostty_dark="$repo_dir/dot/.config/ghostty/themes/seashells"
ghostty_light="$repo_dir/dot/.config/ghostty/themes/seashells-light"
kitty_config="$repo_dir/dot/.config/kitty/kitty.conf"
kitty_dark="$repo_dir/dot/.config/kitty/themes/seashells.conf"
kitty_light="$repo_dir/dot/.config/kitty/themes/seashells-light.conf"
pi_dark="$repo_dir/dot/.pi/agent/themes/seashells.json"
pi_light="$repo_dir/dot/.pi/agent/themes/seashells-light.json"
omp_dark="$repo_dir/dot/.omp/agent/themes/seashells.json"
omp_light="$repo_dir/dot/.omp/agent/themes/seashells-light.json"
omp_config="$repo_dir/dot/.omp/agent/config.yml"

fail() {
    printf 'Seashells palette contract failed: %s\n' "$1" >&2
    exit 1
}

expect_equal() {
    local label=$1 actual=$2 expected=$3
    [[ "$actual" == "$expected" ]] || fail "$label is $actual, expected $expected"
}

ghostty_value() {
    local file=$1 sought=$2
    awk -F '[[:space:]]*=[[:space:]]*' -v sought="$sought" \
        '$1 == sought { value = $2 } END { print value }' "$file"
}

ghostty_ansi_value() {
    local file=$1 sought=$2
    awk -F '[[:space:]]*=[[:space:]]*' -v sought="$sought" \
        '$1 == "palette" && $2 == sought { value = $3 } END { print value }' "$file"
}

kitty_value() {
    local file=$1 sought=$2
    awk -v sought="$sought" '$1 == sought { value = $2 } END { print value }' "$file"
}

assert_native_palette() {
    local label=$1 ghostty=$2 kitty=$3
    shift 3
    local -a expected=("$@")

    expect_equal "$label Ghostty background" "$(ghostty_value "$ghostty" background)" "${expected[0]}"
    expect_equal "$label Ghostty foreground" "$(ghostty_value "$ghostty" foreground)" "${expected[1]}"
    expect_equal "$label Ghostty cursor" "$(ghostty_value "$ghostty" cursor-color)" "${expected[2]}"
    expect_equal "$label Ghostty selection foreground" "$(ghostty_value "$ghostty" selection-foreground)" "${expected[3]}"
    expect_equal "$label Ghostty selection background" "$(ghostty_value "$ghostty" selection-background)" "${expected[4]}"
    expect_equal "$label Kitty background" "$(kitty_value "$kitty" background)" "#${expected[0]}"
    expect_equal "$label Kitty foreground" "$(kitty_value "$kitty" foreground)" "#${expected[1]}"
    expect_equal "$label Kitty cursor" "$(kitty_value "$kitty" cursor)" "#${expected[2]}"
    expect_equal "$label Kitty selection foreground" "$(kitty_value "$kitty" selection_foreground)" "#${expected[3]}"
    expect_equal "$label Kitty selection background" "$(kitty_value "$kitty" selection_background)" "#${expected[4]}"
    for index in {0..15}; do
        expect_equal "$label Ghostty ANSI $index" \
            "$(ghostty_ansi_value "$ghostty" "$index")" "${expected[index + 5]}"
        expect_equal "$label Kitty ANSI $index" \
            "$(kitty_value "$kitty" "color$index")" "#${expected[index + 5]}"
    done
}

dark=(
    08131a deb88d fba02f deb88d 1e4862
    0f2838 d05023 027b9b fba02f 2d6870 68d3f0 50a3b5 deb88d
    424b52 d38677 618c98 fdd29e 1abcdd bbe3ee 86abb3 fee3cd
)
light=(
    e0d6c8 0f2838 d05023 0f2838 c8dde8
    b8a796 d05023 027b9b d88821 2d6870 0f7b8a 50a3b5 0f2838
    4a5a65 d38677 618c98 c57a1a 0e8fb5 2d6870 3a6a75 08131a
)
assert_native_palette dark "$ghostty_dark" "$kitty_dark" "${dark[@]}"
assert_native_palette light "$ghostty_light" "$kitty_light" "${light[@]}"

expect_equal 'Ghostty native variant selector' \
    "$(ghostty_value "$ghostty_config" theme)" 'dark:seashells,light:seashells-light'
expect_equal 'Kitty fallback theme' "$(kitty_value "$kitty_config" include)" 'themes/seashells.conf'
expect_equal 'Kitty dark native variant' \
    "$(kitty_value "$repo_dir/dot/.config/kitty/dark-theme.auto.conf" include)" 'themes/seashells.conf'
expect_equal 'Kitty light native variant' \
    "$(kitty_value "$repo_dir/dot/.config/kitty/light-theme.auto.conf" include)" 'themes/seashells-light.conf'
expect_equal 'Kitty no-preference variant' \
    "$(kitty_value "$repo_dir/dot/.config/kitty/no-preference-theme.auto.conf" include)" 'themes/seashells.conf'

pinned_root='https://github.com/odysseyalive/omarchy-seashells-theme/blob/00dca31761374d5526790dd8a10271edbc6f9ec8/omarchy/themes'
for theme in "$ghostty_dark" "$kitty_dark"; do
    grep -Fxq "# $pinned_root/seashells/colors.toml" "$theme" ||
        fail "$theme does not cite the pinned dark palette"
done
for theme in "$ghostty_light" "$kitty_light"; do
    grep -Fxq "# $pinned_root/seashells-light/colors.toml" "$theme" ||
        fail "$theme does not cite the pinned light palette"
done

expected_dark_vars='{
  "background":"#08131a","foreground":"#deb88d","cursor":"#fba02f","selection":"#1e4862",
  "black":"#0f2838","brightBlack":"#424b52","red":"#d05023","brightRed":"#d38677",
  "green":"#027b9b","brightGreen":"#618c98","yellow":"#fba02f","brightYellow":"#fdd29e",
  "blue":"#2d6870","brightBlue":"#1abcdd","magenta":"#68d3f0","brightMagenta":"#bbe3ee",
  "cyan":"#50a3b5","brightCyan":"#86abb3","white":"#deb88d","brightWhite":"#fee3cd"
}'
expected_light_vars='{
  "background":"#e0d6c8","foreground":"#0f2838","cursor":"#d05023","selection":"#c8dde8",
  "black":"#b8a796","brightBlack":"#4a5a65","red":"#d05023","brightRed":"#d38677",
  "green":"#027b9b","brightGreen":"#618c98","yellow":"#d88821","brightYellow":"#c57a1a",
  "blue":"#2d6870","brightBlue":"#0e8fb5","magenta":"#0f7b8a","brightMagenta":"#2d6870",
  "cyan":"#50a3b5","brightCyan":"#3a6a75","white":"#0f2838","brightWhite":"#08131a"
}'

assert_agent_theme() {
    local theme=$1 schema=$2 name=$3 expected_vars=$4
    jq -e --arg schema "$schema" --arg name "$name" --argjson expected "$expected_vars" '
        ."$schema" == $schema and .name == $name and .vars == $expected and
        .colors.accent == "cyan" and .colors.borderAccent == "cyan" and
        .colors.selectedBg == "selection"
    ' "$theme" >/dev/null || fail "$theme has a mismatched schema, name, palette, or semantic mapping"
}

pi_schema='https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json'
omp_schema='https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/modes/theme/theme-schema.json'
assert_agent_theme "$pi_dark" "$pi_schema" seashells "$expected_dark_vars"
assert_agent_theme "$pi_light" "$pi_schema" seashells-light "$expected_light_vars"
assert_agent_theme "$omp_dark" "$omp_schema" seashells "$expected_dark_vars"
assert_agent_theme "$omp_light" "$omp_schema" seashells-light "$expected_light_vars"
awk '
    $1 == "dark:" && $2 == "seashells" { dark = 1 }
    $1 == "light:" && $2 == "seashells-light" { light = 1 }
    END { exit !(dark && light) }
' "$omp_config" || fail 'OMP does not select both managed theme slots'

if command -v zsh >/dev/null 2>&1; then
    fixture=$(mktemp -d /tmp/dotfiles-seashells-shell.XXXXXX)
    trap 'rm -rf "$fixture"' EXIT
    for variant in dark light; do
        HOME="$fixture" SEASHELLS_VARIANT="$variant" zsh -dfc '
            typeset -g POWERLEVEL9K_DARK_FOREGROUND="#deb88d"
            typeset -g POWERLEVEL9K_LIGHT_FOREGROUND="#e0d6c8"
            source "$1"
            if [[ "$2" == dark ]]; then
                [[ $POWERLEVEL9K_DARK_FOREGROUND == "#deb88d" ]]
                [[ $POWERLEVEL9K_LIGHT_FOREGROUND == 7 ]]
            else
                [[ $POWERLEVEL9K_DARK_FOREGROUND == 7 ]]
                [[ $POWERLEVEL9K_LIGHT_FOREGROUND == "#e0d6c8" ]]
            fi
        ' zsh "$repo_dir/dot/zshrc" "$variant" 2>"$fixture/$variant.stderr" ||
            fail "SEASHELLS_VARIANT=$variant did not select its P10k palette"
    done
fi


printf 'Seashells dark and light palette contracts passed.\n'
