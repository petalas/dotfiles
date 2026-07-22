#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-yazi-config.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-yazi-config.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

version="${YAZI_TEST_VERSION:-}"
if [[ -z "$version" ]]; then
	version=$(curl --retry 3 -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest |
		grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
fi
[[ -n "$version" ]] || { echo "Could not determine the latest Yazi release" >&2; exit 1; }

case "$(uname -s)-$(uname -m)" in
	Darwin-arm64) target="aarch64-apple-darwin" ;;
	Darwin-x86_64) target="x86_64-apple-darwin" ;;
	Linux-x86_64) target="x86_64-unknown-linux-gnu" ;;
	Linux-aarch64|Linux-arm64) target="aarch64-unknown-linux-gnu" ;;
	*) echo "Unsupported Yazi test platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

archive="yazi-${target}.zip"
curl --retry 3 -fsSL \
	"https://github.com/sxyazi/yazi/releases/download/${version}/${archive}" \
	-o "$fixture_dir/$archive"
unzip -q "$fixture_dir/$archive" -d "$fixture_dir/release"

yazi_bin=$(find "$fixture_dir/release" -type f -name yazi -print -quit)
ya_bin=$(find "$fixture_dir/release" -type f -name ya -print -quit)
[[ -x "$yazi_bin" && -x "$ya_bin" ]] || {
	echo "The $version archive did not contain executable yazi and ya binaries" >&2
	exit 1
}
release_dir=$(dirname "$yazi_bin")

cp -R "$repo_dir/dot/.config/yazi" "$fixture_dir/config"
if ! debug_output=$(PATH="$release_dir:$PATH" \
	YAZI_CONFIG_HOME="$fixture_dir/config" \
	"$yazi_bin" --debug </dev/null 2>&1); then
	printf '%s\n' "$debug_output" >&2
	echo "Managed Yazi configuration is incompatible with $version" >&2
	exit 1
fi

cli_version=$("$ya_bin" --version | awk 'NR == 1 { print $2 }')
fm_version=$("$yazi_bin" --version | awk 'NR == 1 { print $2 }')
[[ -n "$cli_version" && "$cli_version" == "$fm_version" ]] || {
	echo "Official $version archive contains mismatched ya/yazi versions" >&2
	exit 1
}

echo "Yazi configuration is valid with latest stable release $version."
