#!/usr/bin/env bash

# Shared Yazi compatibility and package-restoration helpers.
# Yazi requires `ya` and `yazi` to have exactly matching versions, and this
# repository's configuration requires the modern `ya pkg` package manager.

_yazi_version() {
	awk '
		NR == 1 && NF >= 2 { print $2; exit }
		$1 == "Version:" { print $2; exit }
	'
}

yazi_cli_version() {
	local cli
	cli=$(command -v ya) || return 1
	_yazi_binary_version "$cli"
}

yazi_fm_version() {
	local fm
	fm=$(command -v yazi) || return 1
	_yazi_binary_version "$fm"
}

_yazi_binary_version() {
	"$1" --version 2>/dev/null | _yazi_version
}

_yazi_pair_is_compatible() {
	local cli=$1 fm=$2 cli_version fm_version
	[[ -x "$cli" && -x "$fm" ]] || return 1
	cli_version=$(_yazi_binary_version "$cli") || return 1
	fm_version=$(_yazi_binary_version "$fm") || return 1
	[[ -n "$cli_version" && "$cli_version" == "$fm_version" ]] || return 1
	"$cli" pkg --help >/dev/null 2>&1
}

yazi_is_compatible() {
	local cli fm
	cli=$(command -v ya) || return 1
	fm=$(command -v yazi) || return 1
	_yazi_pair_is_compatible "$cli" "$fm"
}

print_yazi_compatibility_error() {
	local cli_path fm_path cli_version fm_version
	cli_path=$(command -v ya 2>/dev/null || printf 'missing')
	fm_path=$(command -v yazi 2>/dev/null || printf 'missing')
	cli_version=$(yazi_cli_version 2>/dev/null || printf 'unknown')
	fm_version=$(yazi_fm_version 2>/dev/null || printf 'unknown')

	printf 'Yazi is incompatible with the managed configuration.\n' >&2
	printf '  ya:   %s (version %s)\n' "$cli_path" "$cli_version" >&2
	printf '  yazi: %s (version %s)\n' "$fm_path" "$fm_version" >&2
	printf 'Expected matching versions with support for `ya pkg`.\n' >&2
}

# Yazi 26.9.1 reads Git symlink blobs as paths, but old caches still have
# actual symlinks. Restore only those index entries without following them.
_yazi_migrate_symlink_cache() {
	[[ "$(yazi_cli_version)" == 26.9.1 ]] || return 0
	local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}" cache entry relative
	[[ "$cache_home" == /* ]] || cache_home="$HOME/.cache"
	[[ -d "$cache_home/yazi/packages" ]] || return 0
	while IFS= read -r -d '' cache; do
		[[ -d "$cache/.git" ]] || continue
		while IFS= read -r -d '' entry; do
			[[ "$entry" == '120000 '* ]] || continue
			relative=${entry#*$'\t'}
			[[ -L "$cache/$relative" ]] || continue
			echo "Migrating Yazi cached symlink: $cache/$relative"
			rm -- "$cache/$relative" || return 1
			git -C "$cache" -c core.symlinks=false checkout-index --force -- "$relative" || return 1
		done < <(git -C "$cache" ls-files --stage -z)
	done < <(find "$cache_home/yazi/packages" -mindepth 1 -maxdepth 1 -type d -print0)
}

install_yazi_packages() {
	local config_home="${YAZI_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/yazi}"

	if ! yazi_is_compatible; then
		print_yazi_compatibility_error
		return 1
	fi
	if [[ ! -f "$config_home/package.toml" ]]; then
		printf 'Yazi package lockfile is missing: %s/package.toml\n' "$config_home" >&2
		return 1
	fi

	echo "Installing locked Yazi packages from $config_home/package.toml"
	_yazi_migrate_symlink_cache || return 1
	YAZI_CONFIG_HOME="$config_home" ya pkg install
}
