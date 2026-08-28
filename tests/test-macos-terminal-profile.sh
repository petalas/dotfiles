#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-macos-terminal.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"

dark_profile="$repo_dir/dot/terminal/SeaShells.terminal"
light_profile="$repo_dir/dot/terminal/Seashells-Light.terminal"
helper="$repo_dir/tools/apply-macos-terminal-profile.js"
generator="$repo_dir/tools/generate-macos-terminal-profile.js"

cat >"$fixture/bin/osascript" <<'EOF'
#!/usr/bin/env bash
echo "unexpected osascript call" >&2
exit 1
EOF
chmod +x "$fixture/bin/osascript"
DOTFILES_OS_OVERRIDE=debian \
DOTFILES_TERMINAL_OSASCRIPT="$fixture/bin/osascript" \
    "$repo_dir/configure-macos-terminal.sh"

cat >"$fixture/bin/fc-list" <<'EOF'
#!/usr/bin/env bash
printf 'Hack Nerd Font Mono:style=Regular\n'
EOF
cat >"$fixture/bin/osascript" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TERMINAL_PROFILE_TEST_LOG"
if [[ "$*" == *apply-macos-terminal-profile.js* ]]; then
    exit "${TERMINAL_PROFILE_OSASCRIPT_STATUS:-0}"
fi
EOF
cat >"$fixture/bin/launchctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TERMINAL_PROFILE_LAUNCHCTL_LOG"
EOF
cat >"$fixture/bin/open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TERMINAL_PROFILE_OPEN_LOG"
EOF
chmod +x "$fixture/bin/fc-list" "$fixture/bin/osascript" "$fixture/bin/launchctl" "$fixture/bin/open"
: >"$fixture/osascript.log"
: >"$fixture/launchctl.log"
: >"$fixture/open.log"
for _ in 1 2; do
    HOME="$fixture/home" PATH="$fixture/bin:/usr/bin:/bin" \
    DOTFILES_OS_OVERRIDE=macos \
    DOTFILES_TERMINAL_OSASCRIPT="$fixture/bin/osascript" \
    DOTFILES_TERMINAL_LAUNCHCTL="$fixture/bin/launchctl" \
    DOTFILES_TERMINAL_OPEN="$fixture/bin/open" \
    TERMINAL_PROFILE_TEST_LOG="$fixture/osascript.log" \
    TERMINAL_PROFILE_LAUNCHCTL_LOG="$fixture/launchctl.log" \
    TERMINAL_PROFILE_OPEN_LOG="$fixture/open.log" \
        "$repo_dir/setup-fonts.sh" >/dev/null
done
[[ $(wc -l <"$fixture/osascript.log") -eq 2 ]]
grep -Fq -- "--profile $dark_profile --profile $light_profile" "$fixture/osascript.log"
[[ ! -s "$fixture/launchctl.log" ]]
[[ ! -s "$fixture/open.log" ]]

: >"$fixture/osascript.log"
: >"$fixture/launchctl.log"
: >"$fixture/open.log"
HOME="$fixture/home" DOTFILES_OS_OVERRIDE=macos \
DOTFILES_TERMINAL_OSASCRIPT="$fixture/bin/osascript" \
DOTFILES_TERMINAL_LAUNCHCTL="$fixture/bin/launchctl" \
DOTFILES_TERMINAL_OPEN="$fixture/bin/open" \
TERMINAL_PROFILE_OSASCRIPT_STATUS=75 \
TERMINAL_PROFILE_TEST_LOG="$fixture/osascript.log" \
TERMINAL_PROFILE_LAUNCHCTL_LOG="$fixture/launchctl.log" \
TERMINAL_PROFILE_OPEN_LOG="$fixture/open.log" \
    "$repo_dir/configure-macos-terminal.sh" >"$fixture/live.out"
grep -Fq 'Imported macOS Terminal profiles Seashells and Seashells Light; Seashells is active.' "$fixture/live.out"
grep -Fxq 'remove com.petalas.dotfiles.terminal-profile' "$fixture/launchctl.log"
[[ $(wc -l <"$fixture/osascript.log") -eq 3 ]]
grep -Fq -- "-g -a Terminal $light_profile $dark_profile" "$fixture/open.log"

if [[ $(uname -s) != Darwin ]]; then
    printf 'macOS Terminal profile shell contracts passed; native checks skipped.\n'
    exit 0
fi

for profile in "$dark_profile" "$light_profile"; do
    plutil -lint "$profile" >/dev/null
    [[ $(plutil -extract columnCount raw "$profile") == 100.000000 ]]
    [[ $(plutil -extract rowCount raw "$profile") == 30.000000 ]]
done
[[ $(plutil -extract name raw "$dark_profile") == Seashells ]]
[[ $(plutil -extract name raw "$light_profile") == 'Seashells Light' ]]

/usr/bin/osascript -l JavaScript "$generator" \
    "$repo_dir/dot/.config/ghostty/config.ghostty" \
    "$repo_dir/dot/.config/ghostty/themes/seashells" Seashells \
    "$fixture/Seashells.terminal"
/usr/bin/osascript -l JavaScript "$generator" \
    "$repo_dir/dot/.config/ghostty/config.ghostty" \
    "$repo_dir/dot/.config/ghostty/themes/seashells-light" 'Seashells Light' \
    >"$fixture/Seashells-Light.terminal"
cmp -s "$dark_profile" "$fixture/Seashells.terminal"
cmp -s "$light_profile" "$fixture/Seashells-Light.terminal"

DARK_PROFILE="$dark_profile" LIGHT_PROFILE="$light_profile" python3 <<'PY'
import base64
import os
import plistlib
import xml.etree.ElementTree as ET

palettes = {
    os.environ["DARK_PROFILE"]: {
        "BackgroundColor": "08131a", "TextColor": "deb88d", "CursorColor": "fba02f",
        "SelectionColor": "1e4862", "SelectedTextColor": "deb88d",
        "ansi": ["0f2838", "d05023", "027b9b", "fba02f", "2d6870", "68d3f0", "50a3b5", "deb88d",
                 "424b52", "d38677", "618c98", "fdd29e", "1abcdd", "bbe3ee", "86abb3", "fee3cd"],
    },
    os.environ["LIGHT_PROFILE"]: {
        "BackgroundColor": "e0d6c8", "TextColor": "0f2838", "CursorColor": "d05023",
        "SelectionColor": "c8dde8", "SelectedTextColor": "0f2838",
        "ansi": ["b8a796", "d05023", "027b9b", "d88821", "2d6870", "0f7b8a", "50a3b5", "0f2838",
                 "4a5a65", "d38677", "618c98", "c57a1a", "0e8fb5", "2d6870", "3a6a75", "08131a"],
    },
}
ansi_keys = [
    "ANSIBlackColor", "ANSIRedColor", "ANSIGreenColor", "ANSIYellowColor",
    "ANSIBlueColor", "ANSIMagentaColor", "ANSICyanColor", "ANSIWhiteColor",
    "ANSIBrightBlackColor", "ANSIBrightRedColor", "ANSIBrightGreenColor", "ANSIBrightYellowColor",
    "ANSIBrightBlueColor", "ANSIBrightMagentaColor", "ANSIBrightCyanColor", "ANSIBrightWhiteColor",
]
for path, expected in palettes.items():
    outer = ET.parse(path).getroot().find("dict")
    children = list(outer)
    blobs = {
        children[index].text: base64.b64decode(children[index + 1].text)
        for index in range(0, len(children), 2)
        if children[index + 1].tag == "data"
    }
    def rgb(key):
        values = plistlib.loads(blobs[key])["$objects"][1]["NSRGB"].rstrip(b"\0").split()
        return tuple(round(float(value) * 255) for value in values[:3])
    def expected_rgb(value):
        return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))
    for key in ("BackgroundColor", "TextColor", "CursorColor", "SelectionColor", "SelectedTextColor"):
        assert rgb(key) == expected_rgb(expected[key]), (path, key, rgb(key), expected[key])
    for key, value in zip(ansi_keys, expected["ansi"]):
        assert rgb(key) == expected_rgb(value), (path, key, rgb(key), value)
PY

sed 's/^function run(argv) {/function productionRun(argv) {/' "$helper" \
    >"$fixture/test-dictionary-bridge.js"
cat >>"$fixture/test-dictionary-bridge.js" <<'EOF'
function run() {
    const message = "Terminal profile must be a dictionary";
    const bridged = $.NSDictionary.dictionaryWithObjectForKey("keep", "TerminalMetadata");
    for (const existing of [bridged, { TerminalMetadata: "keep" }]) {
        const profile = mutableDictionary(existing, message);
        if (ObjC.unwrap(profile.objectForKey("TerminalMetadata")) !== "keep") {
            fail("Terminal profile metadata was not preserved");
        }
    }
    for (const invalid of ["invalid", ["invalid"], function invalid() {}]) {
        let rejected = false;
        try { mutableDictionary(invalid, message); } catch (error) {
            rejected = String(error).includes(message);
        }
        if (!rejected) fail("A non-dictionary Terminal profile was accepted");
    }
}
EOF
/usr/bin/osascript -l JavaScript "$fixture/test-dictionary-bridge.js"

plutil -create xml1 "$fixture/preferences.plist"
plutil -insert Unrelated -string keep "$fixture/preferences.plist"
plutil -insert 'Window Settings' -dictionary "$fixture/preferences.plist"
plutil -insert 'Window Settings.Basic' -dictionary "$fixture/preferences.plist"
plutil -insert 'Window Settings.Basic.name' -string Basic "$fixture/preferences.plist"
for name in Seashells 'Seashells Light'; do
    plutil -insert "Window Settings.$name" -dictionary "$fixture/preferences.plist"
    plutil -insert "Window Settings.$name.TerminalMetadata" -string keep "$fixture/preferences.plist"
done
/usr/bin/osascript -l JavaScript "$helper" -- \
    --profile "$dark_profile" --profile "$light_profile" \
    --preferences-file "$fixture/preferences.plist"
grep -Fxq keep < <(plutil -extract Unrelated raw "$fixture/preferences.plist")
grep -Fxq Basic < <(plutil -extract 'Window Settings.Basic.name' raw "$fixture/preferences.plist")
for name in Seashells 'Seashells Light'; do
    grep -Fxq "$name" < <(plutil -extract "Window Settings.$name.name" raw "$fixture/preferences.plist")
    grep -Fxq keep < <(plutil -extract "Window Settings.$name.TerminalMetadata" raw "$fixture/preferences.plist")
done
grep -Fxq Seashells < <(plutil -extract 'Default Window Settings' raw "$fixture/preferences.plist")
grep -Fxq Seashells < <(plutil -extract 'Startup Window Settings' raw "$fixture/preferences.plist")

first_hash=$(shasum -a 256 "$fixture/preferences.plist" | awk '{print $1}')
/usr/bin/osascript -l JavaScript "$helper" -- \
    --profile "$light_profile" --profile "$dark_profile" \
    --preferences-file "$fixture/preferences.plist"
second_hash=$(shasum -a 256 "$fixture/preferences.plist" | awk '{print $1}')
[[ "$first_hash" == "$second_hash" ]]

if /usr/bin/osascript -l JavaScript "$helper" -- \
    --profile "$dark_profile" --profile "$dark_profile" \
    --preferences-file "$fixture/preferences.plist" >/dev/null 2>&1; then
    echo 'Duplicate Terminal profile modes were accepted.' >&2
    exit 1
fi

printf 'macOS Terminal Seashells dark and light profile tests passed.\n'
