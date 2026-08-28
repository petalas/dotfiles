#!/usr/bin/env bash
# Install both generated Seashells profiles without replacing other Terminal
# profiles. Terminal has no appearance-aware profile selector, so the dark
# profile remains the startup/default profile and the light profile stays
# available by name.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/platform.sh
source "$root_dir/lib/platform.sh"

os=$(dotfiles_os) || { echo "Unsupported OS: $(uname -s)" >&2; exit 1; }
[[ "$os" == macos ]] || exit 0

dark_profile="$root_dir/dot/terminal/SeaShells.terminal"
light_profile="$root_dir/dot/terminal/Seashells-Light.terminal"
helper="$root_dir/tools/apply-macos-terminal-profile.js"
osascript_command=${DOTFILES_TERMINAL_OSASCRIPT:-/usr/bin/osascript}
launchctl_command=${DOTFILES_TERMINAL_LAUNCHCTL:-/bin/launchctl}
open_command=${DOTFILES_TERMINAL_OPEN:-/usr/bin/open}
job_label=com.petalas.dotfiles.terminal-profile

apply_profiles() {
    "$osascript_command" -l JavaScript "$helper" -- \
        --profile "$dark_profile" \
        --profile "$light_profile"
}

if (($#)); then
    echo "Usage: ./configure-macos-terminal.sh" >&2
    exit 2
fi

apply_status=0
apply_profiles || apply_status=$?
if ((apply_status == 0)); then
    exit 0
fi
if ((apply_status != 75)); then
    exit "$apply_status"
fi

# Remove the obsolete deferred job from installations made before live import
# was supported. Terminal owns the live preference write from this point on.
"$launchctl_command" remove "$job_label" >/dev/null 2>&1 || true
existing_window_ids=$(
    "$osascript_command" -e 'tell application "Terminal" to get id of every window' |
        tr -d ' ' | tr ',' '|'
)
"$open_command" -g -a Terminal "$light_profile" "$dark_profile"
"$osascript_command" - "|$existing_window_ids|" <<'APPLESCRIPT'
on run arguments
    set originalWindowIDs to item 1 of arguments
    tell application "Terminal"
        set importWindowCount to 0
        repeat with attempt from 1 to 50
            set importWindowCount to 0
            repeat with terminalWindow in windows
                set windowMarker to "|" & (id of terminalWindow as text) & "|"
                if originalWindowIDs does not contain windowMarker then
                    set importWindowCount to importWindowCount + 1
                end if
            end repeat
            if importWindowCount is at least 2 and (exists settings set "Seashells") and (exists settings set "Seashells Light") then
                exit repeat
            end if
            delay 0.1
        end repeat
        if not (exists settings set "Seashells") then error "Terminal did not import the Seashells profile"
        if not (exists settings set "Seashells Light") then error "Terminal did not import the Seashells Light profile"
        if importWindowCount is less than 2 then error "Terminal did not finish opening both imported profiles"

        set managedProfile to settings set "Seashells"
        set default settings to managedProfile
        set startup settings to managedProfile
        repeat with terminalWindow in windows
            set windowMarker to "|" & (id of terminalWindow as text) & "|"
            if originalWindowIDs contains windowMarker then
                repeat with terminalTab in tabs of terminalWindow
                    set current settings of terminalTab to managedProfile
                end repeat
            else
                do script "exit" in selected tab of terminalWindow
                set visible of terminalWindow to false
            end if
        end repeat

        if font name of managedProfile is not "HackNFM-Regular" then
            error "Seashells did not resolve Hack Nerd Font Mono"
        end if
        if font name of (settings set "Seashells Light") is not "HackNFM-Regular" then
            error "Seashells Light did not resolve Hack Nerd Font Mono"
        end if
    end tell
end run
APPLESCRIPT
echo "Imported macOS Terminal profiles Seashells and Seashells Light; Seashells is active."
