#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-macos-terminal.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"

profile="$repo_dir/dot/terminal/SeaShells.terminal"
helper="$repo_dir/tools/apply-macos-terminal-profile.js"

# The public setup command is a no-op off macOS.
cat >"$fixture/bin/osascript" <<'EOF'
#!/usr/bin/env bash
echo "unexpected osascript call" >&2
exit 1
EOF
chmod +x "$fixture/bin/osascript"
DOTFILES_OS_OVERRIDE=debian \
DOTFILES_TERMINAL_OSASCRIPT="$fixture/bin/osascript" \
    "$repo_dir/configure-macos-terminal.sh"

# The font step configures Terminal even when Hack Nerd Font was already
# installed. This keeps ordinary update reconciliation idempotent.
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
[[ ! -s "$fixture/launchctl.log" ]]
[[ ! -s "$fixture/open.log" ]]

# Exit 75 means Terminal is running. Import through Terminal itself, then apply
# the managed profile to defaults, startup, and every open tab immediately.
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
grep -Fq 'Applied macOS Terminal profile SeaShells to every open tab' "$fixture/live.out"
grep -Fxq 'remove com.petalas.dotfiles.terminal-profile' "$fixture/launchctl.log"
[[ $(wc -l <"$fixture/osascript.log") -eq 3 ]]
grep -Fq 'activate-macos-terminal-profile.applescript' "$fixture/osascript.log"
grep -Fq -- "-g -a Terminal $profile" "$fixture/open.log"

if [[ $(uname -s) != Darwin ]]; then
    printf 'macOS Terminal profile shell contracts passed; native checks skipped.\n'
    exit 0
fi

plutil -lint "$profile" >/dev/null
/usr/bin/osascript -l JavaScript \
    "$repo_dir/tools/generate-macos-terminal-profile.js" \
    "$repo_dir/dot/.config/ghostty/config.ghostty" \
    >"$fixture/SeaShells.terminal"
cmp -s "$profile" "$fixture/SeaShells.terminal"

# NSUserDefaults can expose nested dictionaries through several JXA shapes.
# Exercise each accepted shape and Foundation's invalid-value rejection.
sed 's/^function run(argv) {/function productionRun(argv) {/' "$helper" \
    >"$fixture/test-dictionary-bridge.js"
cat >>"$fixture/test-dictionary-bridge.js" <<'EOF'

function run() {
    const message = "Terminal profile must be a dictionary";
    const bridgedProfile = $.NSDictionary.dictionaryWithObjectForKey(
        "keep",
        "TerminalMetadata"
    );
    const bridgeWithoutClassMethod = new Proxy(bridgedProfile, {
        get(target, key) {
            return key === "isKindOfClass" ? undefined : target[key];
        }
    });
    const nonstandardTagProfile = {
        TerminalMetadata: "keep",
        [Symbol.toStringTag]: "TerminalProfile"
    };
    const profiles = [
        ["Objective-C", bridgedProfile],
        ["class-method-free bridge", bridgeWithoutClassMethod],
        ["nonstandard-tag JavaScript", nonstandardTagProfile],
        ["plain JavaScript", { TerminalMetadata: "keep" }]
    ];
    for (const [label, existingProfile] of profiles) {
        const profile = mutableDictionary(existingProfile, message);
        if (ObjC.unwrap(profile.objectForKey("TerminalMetadata")) !== "keep") {
            fail(`${label} Terminal profile metadata was not preserved`);
        }
    }

    for (const invalid of ["invalid", ["invalid"], function invalid() {}]) {
        let rejected = false;
        try {
            mutableDictionary(invalid, message);
        } catch (error) {
            rejected = String(error).includes(message);
        }
        if (!rejected) {
            fail("A non-dictionary Terminal profile was accepted");
        }
    }
}
EOF
/usr/bin/osascript -l JavaScript "$fixture/test-dictionary-bridge.js"

plutil -extract Font raw -o "$fixture/font.base64" "$profile"
base64 -D <"$fixture/font.base64" >"$fixture/font.archive"
plutil -p "$fixture/font.archive" >"$fixture/font.txt"
grep -Fq 'HackNFM-Regular' "$fixture/font.txt"
[[ $(plutil -extract columnCount raw "$profile") == 100.000000 ]]
[[ $(plutil -extract rowCount raw "$profile") == 30.000000 ]]
[[ $(plutil -extract name raw "$profile") == SeaShells ]]
for color_key in \
    ANSIBlackColor ANSIRedColor ANSIGreenColor ANSIYellowColor \
    ANSIBlueColor ANSIMagentaColor ANSICyanColor ANSIWhiteColor \
    ANSIBrightBlackColor ANSIBrightRedColor ANSIBrightGreenColor \
    ANSIBrightYellowColor ANSIBrightBlueColor ANSIBrightMagentaColor \
    ANSIBrightCyanColor ANSIBrightWhiteColor BackgroundColor \
    TextColor CursorColor SelectionColor SelectedTextColor; do
    plutil -extract "$color_key" raw -o /dev/null "$profile"
done

plutil -create xml1 "$fixture/preferences.plist"
plutil -insert Unrelated -string keep "$fixture/preferences.plist"
plutil -insert 'Window Settings' -dictionary "$fixture/preferences.plist"
plutil -insert 'Window Settings.Basic' -dictionary "$fixture/preferences.plist"
plutil -insert 'Window Settings.Basic.name' -string Basic "$fixture/preferences.plist"
plutil -insert 'Window Settings.SeaShells' -dictionary "$fixture/preferences.plist"
plutil -insert 'Window Settings.SeaShells.TerminalMetadata' -string keep "$fixture/preferences.plist"
/usr/bin/osascript -l JavaScript "$helper" -- \
    --profile "$profile" --preferences-file "$fixture/preferences.plist"
grep -Fxq keep < <(plutil -extract Unrelated raw "$fixture/preferences.plist")
grep -Fxq Basic < <(plutil -extract 'Window Settings.Basic.name' raw "$fixture/preferences.plist")
grep -Fxq SeaShells < <(plutil -extract 'Window Settings.SeaShells.name' raw "$fixture/preferences.plist")
grep -Fxq keep < <(plutil -extract 'Window Settings.SeaShells.TerminalMetadata' raw "$fixture/preferences.plist")
grep -Fxq SeaShells < <(plutil -extract 'Default Window Settings' raw "$fixture/preferences.plist")
grep -Fxq SeaShells < <(plutil -extract 'Startup Window Settings' raw "$fixture/preferences.plist")

first_hash=$(shasum -a 256 "$fixture/preferences.plist" | awk '{print $1}')
/usr/bin/osascript -l JavaScript "$helper" -- \
    --profile "$profile" --preferences-file "$fixture/preferences.plist"
second_hash=$(shasum -a 256 "$fixture/preferences.plist" | awk '{print $1}')
[[ "$first_hash" == "$second_hash" ]]

plutil -create xml1 "$fixture/invalid-preferences.plist"
plutil -insert 'Window Settings' -string invalid "$fixture/invalid-preferences.plist"
invalid_hash=$(shasum -a 256 "$fixture/invalid-preferences.plist" | awk '{print $1}')
if /usr/bin/osascript -l JavaScript "$helper" -- \
    --profile "$profile" --preferences-file "$fixture/invalid-preferences.plist" \
    >/dev/null 2>&1; then
    echo "Invalid Terminal preferences were accepted." >&2
    exit 1
fi
[[ "$invalid_hash" == "$(shasum -a 256 "$fixture/invalid-preferences.plist" | awk '{print $1}')" ]]

printf 'macOS Terminal SeaShells profile tests passed.\n'
