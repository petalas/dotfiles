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
# Yazi loads configuration before --help, and requires a terminal for it.
if ! PATH="$release_dir:$PATH" YAZI_CONFIG_HOME="$fixture_dir/config" \
    python3 - "$yazi_bin" >"$fixture_dir/debug.log" <<'PYTHON'
import errno
import os
import pty
import subprocess
import select
import time
import sys

master, slave = pty.openpty()
try:
    process = subprocess.Popen([sys.argv[1], "--help"], stdin=slave, stdout=slave, stderr=slave)
    os.close(slave)
    deadline = time.monotonic() + 30
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([master], [], [], remaining)[0]:
            process.kill()
            process.wait()
            raise TimeoutError("Yazi configuration probe timed out")
        try:
            data = os.read(master, 65536)
        except OSError as error:
            if error.errno != errno.EIO:
                raise
            break
        if not data:
            break
        sys.stdout.buffer.write(data)
    sys.exit(process.wait(timeout=30))
finally:
    os.close(master)
PYTHON
then
    cat "$fixture_dir/debug.log" >&2
    echo "Managed Yazi configuration is incompatible with $version" >&2
    exit 1
fi

version_from_output() {
	awk 'NR == 1 && NF >= 2 { print $2; exit } $1 == "Version:" { print $2; exit }'
}
cli_version=$("$ya_bin" --version | version_from_output)
fm_version=$("$yazi_bin" --version | version_from_output)
[[ -n "$cli_version" && "$cli_version" == "$fm_version" ]] || {
	echo "Official $version archive contains mismatched ya/yazi versions" >&2
	exit 1
}

# Exercise package restoration and repeatability with the real release binary.
# Seed the old cache format that existed before Yazi 26.9.1.
export XDG_CACHE_HOME="$fixture_dir/cache"
legacy_cache="$XDG_CACHE_HOME/yazi/packages/89c23501b37716e3dfefb092388d1d58"
git clone --quiet https://github.com/kirasok/torrent-preview.yazi.git "$legacy_cache"
git -C "$legacy_cache" checkout --quiet 4ca5996
# shellcheck source=lib/yazi.sh
source "$repo_dir/lib/yazi.sh"
for pass in 1 2; do
    echo "Package restoration pass $pass"
    PATH="$release_dir:$PATH" YAZI_CONFIG_HOME="$fixture_dir/config" install_yazi_packages
    cmp "$repo_dir/dot/.config/yazi/package.toml" "$fixture_dir/config/package.toml"
done

echo "Yazi configuration is valid with latest stable release $version."
