#!/usr/bin/env bash

_yazi_installer_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/yazi.sh disable=SC1091
source "$_yazi_installer_root/lib/yazi.sh"
unset _yazi_installer_root

_yazi_release_layout() {
	local os=$1 machine=$2 target
	case "$os:$machine" in
		macos:x86_64|macos:amd64) target=x86_64-apple-darwin ;;
		macos:arm64|macos:aarch64) target=aarch64-apple-darwin ;;
		ubuntu:x86_64|ubuntu:amd64|debian:x86_64|debian:amd64) target=x86_64-unknown-linux-gnu ;;
		ubuntu:arm64|ubuntu:aarch64|debian:arm64|debian:aarch64) target=aarch64-unknown-linux-gnu ;;
		*) return 1 ;;
	esac
	printf 'yazi-%s.zip\tyazi-%s\n' "$target" "$target"
}

_yazi_release_asset() {
	local asset=$1 metadata record tag url digest
	metadata=$(download_stdout https://api.github.com/repos/sxyazi/yazi/releases/latest) || return 1
	record=$(printf '%s' "$metadata" | jq -er --arg asset "$asset" '
		[.assets[] | select(.name == $asset)] as $matches |
		if (.tag_name | type) == "string" and ($matches | length) == 1 then
			[.tag_name, $matches[0].browser_download_url, $matches[0].digest] | @tsv
		else
			error("release asset missing or duplicated")
		end
	') || return 1
	IFS=$'\t' read -r tag url digest <<<"$record"
	digest=${digest#sha256:}
	[[ "$tag" == v* &&
		"$url" == "https://github.com/sxyazi/yazi/releases/download/$tag/$asset" &&
		"$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
	printf '%s\t%s\t%s\n' "$tag" "$url" "$(printf '%s' "$digest" | tr '[:upper:]' '[:lower:]')"
}

_yazi_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{ print $1 }'
	else
		shasum -a 256 "$1" | awk '{ print $1 }'
	fi
}

install_yazi() {
	local os layout asset dirname release tag url expected actual work_dir archive extracted
	local data_home target target_parent stage backup bin_dir ya_launcher yazi_launcher
	local temporary_ya temporary_yazi launcher
	os=$(dotfiles_os) || return 1
	if [[ "$os" == arch ]]; then
		linux_packages_install yazi || return 1
		if ! yazi_is_compatible; then
			print_yazi_compatibility_error
			return 1
		fi
		return 0
	fi

	layout=$(_yazi_release_layout "$os" "$(uname -m)") || {
		echo "The official Yazi release is unavailable for $os/$(uname -m)." >&2
		return 1
	}
	IFS=$'\t' read -r asset dirname <<<"$layout"
	release=$(_yazi_release_asset "$asset") || {
		echo "Could not resolve the official Yazi release asset." >&2
		return 1
	}
	IFS=$'\t' read -r tag url expected <<<"$release"

	data_home=${XDG_DATA_HOME:-$HOME/.local/share}
	target="$data_home/yazi-release"
	target_parent=${target%/*}
	bin_dir="$HOME/.local/bin"
	ya_launcher="$bin_dir/ya"
	yazi_launcher="$bin_dir/yazi"
	for launcher in "$ya_launcher" "$yazi_launcher"; do
		if [[ -e "$launcher" && ! -L "$launcher" ]]; then
			echo "Refusing to replace non-symlink Yazi launcher: $launcher" >&2
			return 1
		fi
	done

	work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-yazi.XXXXXX") || return 1
	archive="$work_dir/$asset"
	echo "Installing Yazi ${tag#v} from its official release..."
	if ! download_file "$url" "$archive"; then
		rm -rf "$work_dir"
		return 1
	fi
	actual=$(_yazi_sha256 "$archive") || {
		rm -rf "$work_dir"
		return 1
	}
	actual=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')
	if [[ "$actual" != "$expected" ]]; then
		printf 'Checksum mismatch for %s\nExpected: %s\nActual:   %s\n' \
			"$asset" "$expected" "$actual" >&2
		rm -rf "$work_dir"
		return 1
	fi
	if ! unzip -q "$archive" -d "$work_dir"; then
		rm -rf "$work_dir"
		return 1
	fi
	extracted="$work_dir/$dirname"
	if ! _yazi_pair_is_compatible "$extracted/ya" "$extracted/yazi"; then
		echo "The official Yazi release does not contain a compatible ya/yazi pair." >&2
		rm -rf "$work_dir"
		return 1
	fi

	mkdir -p "$target_parent" "$bin_dir" || {
		rm -rf "$work_dir"
		return 1
	}
	stage=$(mktemp -d "$target_parent/.yazi-release.XXXXXX") || {
		rm -rf "$work_dir"
		return 1
	}
	if ! cp -a "$extracted/." "$stage/"; then
		rm -rf "$work_dir" "$stage"
		return 1
	fi
	rm -rf "$work_dir"

	backup="$target_parent/.yazi-release.previous.$$"
	rm -rf "$backup"
	if [[ -e "$target" ]] && ! mv "$target" "$backup"; then
		rm -rf "$stage"
		return 1
	fi
	if ! mv "$stage" "$target"; then
		[[ ! -e "$backup" ]] || mv "$backup" "$target" || true
		return 1
	fi

	temporary_ya="$bin_dir/.ya.$$"
	temporary_yazi="$bin_dir/.yazi.$$"
	rm -f "$temporary_ya" "$temporary_yazi"
	if ! ln -s "$target/ya" "$temporary_ya" ||
		! ln -s "$target/yazi" "$temporary_yazi" ||
		! mv -f "$temporary_ya" "$ya_launcher" ||
		! mv -f "$temporary_yazi" "$yazi_launcher"; then
		rm -f "$temporary_ya" "$temporary_yazi"
		rm -rf "$target"
		[[ ! -e "$backup" ]] || mv "$backup" "$target" || true
		return 1
	fi
	rm -rf "$backup"

	PATH="$bin_dir:$PATH"
	export PATH
	hash -r 2>/dev/null || true
	if [[ $(command -v ya 2>/dev/null) != "$ya_launcher" ||
		$(command -v yazi 2>/dev/null) != "$yazi_launcher" ]] || ! yazi_is_compatible; then
		print_yazi_compatibility_error
		return 1
	fi

	# Remove the obsolete meta-package when migrating a machine that previously
	# used this repository's Cargo-based provider. Its nested installer can
	# report success without producing the Yazi binaries.
	if command -v cargo >/dev/null 2>&1 &&
		cargo install --list 2>/dev/null | grep -q '^yazi-build v[^:]*:$'; then
		cargo uninstall yazi-build >/dev/null 2>&1 ||
			echo "Warning: could not remove the obsolete yazi-build package." >&2
	fi

	echo "yazi $(yazi_fm_version) is installed with a matching ya CLI."
}
