#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-apt-mirrors.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-apt-mirrors.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

assert_contains() {
	local expected="$1"
	local file="$2"
	grep -Fq "$expected" "$file" || {
		echo "Expected $file to contain: $expected" >&2
		exit 1
	}
}

assert_not_contains() {
	local unexpected="$1"
	local file="$2"
	if grep -Fq "$unexpected" "$file"; then
		echo "Expected $file not to contain: $unexpected" >&2
		exit 1
	fi
}

ubuntu_root="$fixture_dir/ubuntu"
mkdir -p "$ubuntu_root/sources.list.d"
cat >"$ubuntu_root/sources.list" <<'EOF'
deb http://archive.ubuntu.com/ubuntu noble main universe
deb http://security.ubuntu.com/ubuntu noble-security main universe
deb https://ppa.launchpadcontent.net/example/stable/ubuntu noble main
EOF
cat >"$ubuntu_root/sources.list.d/ubuntu.sources" <<'EOF'
Types: deb
URIs: https://gb.archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main universe

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main universe
EOF

APT_SOURCES_ROOT="$ubuntu_root" APT_MIRROR_OS_ID=ubuntu "$repo_dir/setup-apt-mirrors.sh"
assert_contains 'mirror+http://mirrors.ubuntu.com/mirrors.txt' "$ubuntu_root/sources.list"
assert_contains 'mirror+http://mirrors.ubuntu.com/mirrors.txt' "$ubuntu_root/sources.list.d/ubuntu.sources"
assert_contains 'http://security.ubuntu.com/ubuntu' "$ubuntu_root/sources.list"
assert_contains 'http://security.ubuntu.com/ubuntu/' "$ubuntu_root/sources.list.d/ubuntu.sources"
assert_contains 'https://ppa.launchpadcontent.net/example/stable/ubuntu' "$ubuntu_root/sources.list"
assert_not_contains 'archive.ubuntu.com/ubuntu' "$ubuntu_root/sources.list"
assert_not_contains 'archive.ubuntu.com/ubuntu' "$ubuntu_root/sources.list.d/ubuntu.sources"
assert_contains 'http://archive.ubuntu.com/ubuntu' "$ubuntu_root/.dotfiles-backups/sources.list"

ubuntu_checksum=$(find "$ubuntu_root" -type f ! -path '*/.dotfiles-backups/*' -exec cksum {} + | sort)
APT_SOURCES_ROOT="$ubuntu_root" APT_MIRROR_OS_ID=ubuntu "$repo_dir/setup-apt-mirrors.sh"
[[ "$ubuntu_checksum" == "$(find "$ubuntu_root" -type f ! -path '*/.dotfiles-backups/*' -exec cksum {} + | sort)" ]] || {
	echo "Ubuntu mirror configuration is not idempotent" >&2
	exit 1
}

ubuntu_override_root="$fixture_dir/ubuntu-override"
mkdir -p "$ubuntu_override_root"
cat >"$ubuntu_override_root/sources.list" <<'EOF'
deb http://archive.ubuntu.com/ubuntu noble main universe
deb http://security.ubuntu.com/ubuntu noble-security main universe
EOF
APT_SOURCES_ROOT="$ubuntu_override_root" \
	APT_MIRROR_OS_ID=ubuntu \
	APT_PRIMARY_MIRROR=http://us.archive.ubuntu.com/ubuntu \
	"$repo_dir/setup-apt-mirrors.sh"
assert_contains 'http://us.archive.ubuntu.com/ubuntu' "$ubuntu_override_root/sources.list"
assert_not_contains 'mirrors.ubuntu.com' "$ubuntu_override_root/sources.list"
assert_contains 'http://security.ubuntu.com/ubuntu' "$ubuntu_override_root/sources.list"

ubuntu_security_override_root="$fixture_dir/ubuntu-security-override"
mkdir -p "$ubuntu_security_override_root"
cat >"$ubuntu_security_override_root/sources.list" <<'EOF'
deb http://archive.ubuntu.com/ubuntu noble main universe
deb http://security.ubuntu.com/ubuntu noble-security main universe
EOF
APT_SOURCES_ROOT="$ubuntu_security_override_root" \
	APT_MIRROR_OS_ID=ubuntu \
	APT_PRIMARY_MIRROR=http://us.archive.ubuntu.com/ubuntu \
	APT_SECURITY_MIRROR=http://security-mirror.example.com/ubuntu \
	"$repo_dir/setup-apt-mirrors.sh"
assert_contains 'http://us.archive.ubuntu.com/ubuntu' "$ubuntu_security_override_root/sources.list"
assert_contains 'http://security-mirror.example.com/ubuntu' "$ubuntu_security_override_root/sources.list"
assert_not_contains 'security.ubuntu.com' "$ubuntu_security_override_root/sources.list"

debian_root="$fixture_dir/debian"
mkdir -p "$debian_root/sources.list.d"
cat >"$debian_root/sources.list" <<'EOF'
deb http://ftp.us.debian.org/debian bookworm main
deb https://security.debian.org/debian-security bookworm-security main
deb https://packages.example.com/debian stable main
EOF
cat >"$debian_root/sources.list.d/debian.sources" <<'EOF'
Types: deb
URIs: http://ftp.debian.org/debian/
Suites: bookworm bookworm-updates
Components: main
EOF

APT_SOURCES_ROOT="$debian_root" APT_MIRROR_OS_ID=debian "$repo_dir/setup-apt-mirrors.sh"
assert_contains 'http://deb.debian.org/debian' "$debian_root/sources.list"
assert_contains 'http://deb.debian.org/debian-security' "$debian_root/sources.list"
assert_contains 'http://deb.debian.org/debian' "$debian_root/sources.list.d/debian.sources"
assert_contains 'https://packages.example.com/debian' "$debian_root/sources.list"
assert_not_contains 'ftp.us.debian.org' "$debian_root/sources.list"
assert_not_contains 'security.debian.org' "$debian_root/sources.list"
assert_contains 'http://ftp.us.debian.org/debian' "$debian_root/.dotfiles-backups/sources.list"

echo "APT mirror configuration tests passed."
