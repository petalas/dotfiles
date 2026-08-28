#!/usr/bin/env bash
# Install the generated SeaShells profile without replacing other Terminal
# profiles. Running instances import through Terminal itself so their existing
# tabs can adopt the profile immediately.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/platform.sh
source "$root_dir/lib/platform.sh"

os=$(dotfiles_os) || { echo "Unsupported OS: $(uname -s)" >&2; exit 1; }
[[ "$os" == macos ]] || exit 0

profile="$root_dir/dot/terminal/SeaShells.terminal"
helper="$root_dir/tools/apply-macos-terminal-profile.js"
osascript_command=${DOTFILES_TERMINAL_OSASCRIPT:-/usr/bin/osascript}
launchctl_command=${DOTFILES_TERMINAL_LAUNCHCTL:-/bin/launchctl}
open_command=${DOTFILES_TERMINAL_OPEN:-/usr/bin/open}
job_label=com.petalas.dotfiles.terminal-profile
activator="$root_dir/tools/activate-macos-terminal-profile.applescript"

apply_profile() {
    "$osascript_command" -l JavaScript "$helper" -- --profile "$profile"
}

if (($#)); then
    echo "Usage: ./configure-macos-terminal.sh" >&2
    exit 2
fi

apply_status=0
apply_profile || apply_status=$?
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
"$open_command" -g -a Terminal "$profile"
"$osascript_command" "$activator" "|$existing_window_ids|"
echo "Applied macOS Terminal profile SeaShells to every open tab."
