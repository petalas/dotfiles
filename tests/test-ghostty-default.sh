#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-ghostty-default.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-ghostty-default.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

export HOME="$fixture_dir/home"
export XDG_CONFIG_HOME="$fixture_dir/xdg-config"
export XDG_DATA_HOME="$fixture_dir/xdg-data"
export XDG_DATA_DIRS="$fixture_dir/system-data"
mkdir -p \
	"$HOME" \
	"$XDG_DATA_HOME/applications" \
	"$XDG_DATA_DIRS/applications"

# shellcheck source=../installers/install_ghostty.sh
source "$repo_dir/installers/install_ghostty.sh"

# Linux should honor XDG paths and select an installed desktop entry.
os_id=ubuntu
touch "$XDG_DATA_HOME/applications/ghostty.desktop"
set_ghostty_default_terminal
[[ "$(cat "$XDG_CONFIG_HOME/xdg-terminals.list")" == "ghostty.desktop" ]]

# Prefer Ghostty's canonical app ID when both desktop entry names exist.
touch "$XDG_DATA_HOME/applications/com.mitchellh.ghostty.desktop"
set_ghostty_default_terminal
[[ "$(cat "$XDG_CONFIG_HOME/xdg-terminals.list")" == "com.mitchellh.ghostty.desktop" ]]

# Exercise the non-interactive macOS path with xcrun and Swift test doubles.
# The generated Swift source must use the same public API as Ghostty's menu item.
mkdir -p "$fixture_dir/bin" "$fixture_dir/Ghostty.app"
export GHOSTTY_APP_PATH="$fixture_dir/Ghostty.app"
export GHOSTTY_TEST_LOG="$fixture_dir/swift-args"
export GHOSTTY_TEST_SOURCE="$fixture_dir/set-default.swift"
export GHOSTTY_TEST_SWIFT="$fixture_dir/bin/swift"

cat >"$fixture_dir/bin/xcrun" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "--find swift" ]]
printf '%s\n' "$GHOSTTY_TEST_SWIFT"
EOF
cat >"$fixture_dir/bin/swift" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$GHOSTTY_TEST_LOG"
cat >"$GHOSTTY_TEST_SOURCE"
EOF
chmod +x "$fixture_dir/bin/xcrun" "$fixture_dir/bin/swift"

os_id=macos
PATH="$fixture_dir/bin:/usr/bin:/bin" set_ghostty_default_terminal
[[ "$(cat "$GHOSTTY_TEST_LOG")" == "- $GHOSTTY_APP_PATH" ]]
grep -Fq 'NSWorkspace.shared.setDefaultApplication' "$GHOSTTY_TEST_SOURCE"
grep -Fq '.unixExecutable' "$GHOSTTY_TEST_SOURCE"
grep -Fq '.shellScript' "$GHOSTTY_TEST_SOURCE"
grep -Fq 'com.apple.terminal.shell-script' "$GHOSTTY_TEST_SOURCE"

# A failed native association must fail the installer rather than claiming
# setup completed successfully.
cat >"$fixture_dir/bin/swift" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 1
EOF
chmod +x "$fixture_dir/bin/swift"
if PATH="$fixture_dir/bin:/usr/bin:/bin" set_ghostty_default_terminal; then
	echo "Expected a failed macOS default-terminal association to propagate" >&2
	exit 1
fi

echo "Ghostty default-terminal tests passed."
