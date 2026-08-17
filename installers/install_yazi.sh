#!/usr/bin/env bash

_yazi_installer_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/yazi.sh disable=SC1091
source "$_yazi_installer_root/lib/yazi.sh"
unset _yazi_installer_root

install_yazi() {
	local os
	os=$(dotfiles_os) || return 1
	if [[ "$os" == arch ]]; then
		linux_packages_install yazi || return 1
		if ! yazi_is_compatible; then
			print_yazi_compatibility_error
			return 1
		fi
		return 0
	fi

	if ! command -v cargo >/dev/null 2>&1; then
		echo "Yazi requires Cargo; run the Rust installer first." >&2
		return 1
	fi

	# Without --force, Cargo checks crates.io and upgrades yazi-build only when
	# a newer release exists. yazi-build then installs matching yazi-fm/yazi-cli
	# releases, giving us the latest stable pair without recompiling every run.
	echo "Installing/updating yazi..."
	cargo install --locked yazi-build || return 1

	if ! yazi_is_compatible; then
		# Repair missing, stale, or mismatched child binaries even when Cargo
		# considers the yazi-build meta-package itself current.
		echo "Repairing yazi component installation..."
		cargo install --force --locked yazi-build || return 1
	fi

	if ! yazi_is_compatible; then
		print_yazi_compatibility_error
		return 1
	fi

	echo "yazi $(yazi_fm_version) is installed with a matching ya CLI."
}
