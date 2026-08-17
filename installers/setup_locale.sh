#!/usr/bin/env bash

setup_locale() {
	local locale_name="en_US.UTF-8"
	local locale_gen_file="/etc/locale.gen"
	local os

	os=$(dotfiles_os) || {
		echo "Unsupported OS for locale setup." >&2
		return 1
	}
	if [[ "$os" == macos ]]; then
		if LC_ALL="$locale_name" locale charmap 2>/dev/null | grep -qx "UTF-8"; then
			echo "UTF-8 locale already available: $locale_name"
			return 0
		fi
		echo "Locale is not available on macOS: $locale_name" >&2
		return 1
	fi

	if [[ "$os" == "ubuntu" || "$os" == "debian" ]] &&
		{ [[ ! -f "$locale_gen_file" ]] || ! command -v locale-gen >/dev/null 2>&1; }; then
		echo "Installing locale support..."
		LC_ALL=C LANG=C linux_packages_refresh
		LC_ALL=C LANG=C linux_packages_install locales
	fi

	if [[ ! -f "$locale_gen_file" ]]; then
		echo "$locale_gen_file not found; install the system locales package first" >&2
		return 1
	fi

	# Debian, Ubuntu, and Arch all use /etc/locale.gen. Keep the update
	# idempotent and leave any other explicitly enabled locales intact.
	if ! grep -Eq '^[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8([[:space:]]|$)' "$locale_gen_file"; then
		printf '\nen_US.UTF-8 UTF-8\n' | run_as_root tee -a "$locale_gen_file" >/dev/null
	fi

	run_as_root locale-gen

	if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
		# Passing a variable without a value removes it. Use LANG as the default
		# instead of category overrides that SSH may forward independently.
		run_as_root update-locale LANG="$locale_name" LC_ALL LC_CTYPE
	else
		if command -v localectl >/dev/null 2>&1 && run_as_root localectl set-locale LANG="$locale_name"; then
			:
		else
			# localectl may be unavailable in a chroot or container.
			if [[ -f /etc/locale.conf ]] && grep -q '^LANG=' /etc/locale.conf; then
				run_as_root sed -i "s/^LANG=.*/LANG=$locale_name/" /etc/locale.conf
			else
				printf 'LANG=%s\n' "$locale_name" | run_as_root tee -a /etc/locale.conf >/dev/null
			fi
		fi
		run_as_root sed -i -E '/^(LC_ALL|LC_CTYPE)=/d' /etc/locale.conf
	fi

	if ! LC_ALL="$locale_name" locale charmap 2>/dev/null | grep -qx "UTF-8"; then
		echo "Failed to generate UTF-8 locale: $locale_name" >&2
		return 1
	fi

	echo "UTF-8 locale configured: $locale_name"
}
