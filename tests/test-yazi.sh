#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=$(mktemp -d /tmp/dotfiles-yazi.XXXXXX)

cleanup() {
	case "$fixture_dir" in
		/tmp/dotfiles-yazi.*) rm -r -- "$fixture_dir" ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture_dir/bin"
export HOME="$fixture_dir/home"
export YAZI_TEST_STATE="$fixture_dir/state"
export YAZI_TEST_SCENARIO="$fixture_dir/scenario"
export YAZI_TEST_LOG="$fixture_dir/commands"
export YAZI_CONFIG_HOME="$fixture_dir/yazi-config"
mkdir -p "$HOME" "$YAZI_CONFIG_HOME"
touch "$YAZI_CONFIG_HOME/package.toml"

cat >"$fixture_dir/bin/ya" <<'EOF'
#!/usr/bin/env bash
state=$(cat "$YAZI_TEST_STATE")

if [[ "${1:-}" == "--version" ]]; then
	case "$state" in
		legacy) echo "Ya 25.4.8 (test)" ;;
		mismatch|modern) echo "Ya 26.9.1 (test)" ;;
		multiline) printf 'Ya\n    Version: 26.8.15 (test)\n' ;;
		*) exit 1 ;;
	esac
	exit 0
fi

if [[ "${1:-}" == "pkg" && "${2:-}" == "--help" ]]; then
	[[ "$state" == "modern" || "$state" == "mismatch" || "$state" == "multiline" ]]
	exit
fi

if [[ "${1:-}" == "pkg" && "${2:-}" == "install" ]]; then
	if [[ -L ${XDG_CACHE_HOME:-$HOME/.cache}/yazi/packages/fixture/init.lua ]]; then
		echo 'failed to resolve Git symlink target: File name too long' >&2
		exit 1
	fi
	printf 'ya:%s\n' "$*" >>"$YAZI_TEST_LOG"
	[[ "$state" == "modern" ]]
	exit
fi

exit 2
EOF

cat >"$fixture_dir/bin/yazi" <<'EOF'
#!/usr/bin/env bash
state=$(cat "$YAZI_TEST_STATE")

if [[ "${1:-}" == "--version" ]]; then
	case "$state" in
		legacy|mismatch) echo "Yazi 25.4.8 (test)" ;;
		modern) echo "Yazi 26.9.1 (test)" ;;
		multiline) printf 'Yazi\n    Version: 26.8.15 (test)\n' ;;
		*) exit 1 ;;
	esac
	exit 0
fi

exit 2
EOF

cat >"$fixture_dir/bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo:%s\n' "$*" >>"$YAZI_TEST_LOG"
case "$*" in
	'install --list') printf 'yazi-build v26.8.15:\n    yazi-build\n' ;;
	'uninstall yazi-build') ;;
	*) exit 2 ;;
esac
EOF

chmod +x "$fixture_dir/bin/ya" "$fixture_dir/bin/yazi" "$fixture_dir/bin/cargo"
export PATH="$fixture_dir/bin:$PATH"

export DOTFILES_OS_OVERRIDE=debian
# shellcheck source=../installers/source_installers.sh disable=SC1091
source "$repo_dir/installers/source_installers.sh"
uname() {
	[[ "${1:-}" == -m ]] && { printf 'x86_64\n'; return; }
	command uname "$@"
}

assert_log_line() {
	local expected="$1"
	grep -Fqx "$expected" "$YAZI_TEST_LOG" || {
		echo "Expected command log to contain: $expected" >&2
		exit 1
	}
}

assert_no_log_line() {
	local unexpected="$1"
	if grep -Fqx "$unexpected" "$YAZI_TEST_LOG"; then
		echo "Expected command log not to contain: $unexpected" >&2
		exit 1
	fi
}

# Current Yazi releases print a multiline version block.
printf 'multiline\n' >"$YAZI_TEST_STATE"
yazi_is_compatible
[[ "$(yazi_cli_version)" == 26.8.15 ]]
[[ "$(yazi_fm_version)" == 26.8.15 ]]

# Old or mismatched pairs remain incompatible before replacement.
printf 'legacy\n' >"$YAZI_TEST_STATE"
if yazi_is_compatible; then
	echo "Expected the legacy Yazi pair to be incompatible" >&2
	exit 1
fi
printf 'mismatch\n' >"$YAZI_TEST_STATE"
if yazi_is_compatible; then
	echo "Expected mismatched Yazi versions to be incompatible" >&2
	exit 1
fi

# A successful yazi-build installation is not proof that its nested installer
# produced ya/yazi. Install and select the checksummed official release pair
# without relying on the meta-package's build-script side effects.
download_stdout() {
	cat <<'EOF'
{"tag_name":"v26.8.15","assets":[{"name":"yazi-x86_64-unknown-linux-gnu.zip","digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","browser_download_url":"https://github.com/sxyazi/yazi/releases/download/v26.8.15/yazi-x86_64-unknown-linux-gnu.zip"}]}
EOF
}
download_file() {
	printf 'download:%s\n' "$1" >>"$YAZI_TEST_LOG"
	printf 'archive\n' >"$2"
}
# shellcheck disable=SC2317 # Called indirectly by install_yazi.
_yazi_sha256() {
	printf '%064d\n' 0 | tr 0 a
}
unzip() {
	local destination=${4:?}
	local extracted="$destination/yazi-x86_64-unknown-linux-gnu"
	mkdir -p "$extracted"
	cp "$fixture_dir/bin/ya" "$extracted/ya"
	cp "$fixture_dir/bin/yazi" "$extracted/yazi"
}
printf 'modern\n' >"$YAZI_TEST_STATE"
: >"$YAZI_TEST_LOG"
install_yazi >/dev/null
[[ $(command -v ya) == "$HOME/.local/bin/ya" ]]
[[ $(command -v yazi) == "$HOME/.local/bin/yazi" ]]
assert_log_line 'download:https://github.com/sxyazi/yazi/releases/download/v26.8.15/yazi-x86_64-unknown-linux-gnu.zip'
assert_no_log_line 'cargo:install --locked yazi-build'
assert_log_line 'cargo:uninstall yazi-build'

[[ $(_yazi_release_layout macos arm64) == $'yazi-aarch64-apple-darwin.zip\tyazi-aarch64-apple-darwin' ]]
[[ $(_yazi_release_layout ubuntu x86_64) == $'yazi-x86_64-unknown-linux-gnu.zip\tyazi-x86_64-unknown-linux-gnu' ]]
if _yazi_release_layout debian mips64 >/dev/null; then
	echo "Expected an unsupported Yazi architecture to be rejected" >&2
	exit 1
fi

# A bad release checksum must not replace the selected pair.
# shellcheck disable=SC2317 # Called indirectly by install_yazi.
_yazi_sha256() {
	printf '%064d\n' 0 | tr 0 b
}
: >"$YAZI_TEST_LOG"
if install_yazi >/dev/null 2>&1; then
	echo "Expected install_yazi to reject a bad release checksum" >&2
	exit 1
fi
[[ $(command -v ya) == "$HOME/.local/bin/ya" ]]
[[ $(command -v yazi) == "$HOME/.local/bin/yazi" ]]

# package.toml is canonical: restore its locked dependencies in one operation
# instead of re-adding and potentially rewriting each dependency.
printf 'modern\n' >"$YAZI_TEST_STATE"
: >"$YAZI_TEST_LOG"
install_yazi_packages
assert_log_line 'ya:pkg install'
if grep -Fq 'pkg add' "$YAZI_TEST_LOG"; then
	echo "Yazi packages must be restored from package.toml, not re-added" >&2
	exit 1
fi

# Existing pre-26.9.1 caches contain real Git symlinks.
export XDG_CACHE_HOME="$fixture_dir/cache"
package_cache="$XDG_CACHE_HOME/yazi/packages/fixture"
mkdir -p "$package_cache"
git init --quiet "$package_cache"
printf 'return {}\n' >"$package_cache/main.lua"
ln -s main.lua "$package_cache/init.lua"
git -C "$package_cache" add main.lua init.lua
printf 'keep\n' >"$package_cache/untracked"
install_yazi_packages
[[ ! -L "$package_cache/init.lua" ]]
[[ "$(cat "$package_cache/init.lua")" == main.lua ]]
[[ "$(cat "$package_cache/main.lua")" == 'return {}' ]]
[[ "$(cat "$package_cache/untracked")" == keep ]]
install_yazi_packages

echo "Yazi installer tests passed."
