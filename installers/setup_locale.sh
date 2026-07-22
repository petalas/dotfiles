#!/usr/bin/env bash
# shellcheck disable=SC2154  # $os_id provided by source_installers.sh

setup_locale() {
	local locale_name="en_US.UTF-8"
	local locale_gen_file="/etc/locale.gen"

	if [[ "$OSTYPE" == darwin* ]]; then
		if LC_ALL="$locale_name" locale charmap 2>/dev/null | grep -qx "UTF-8"; then
			echo "UTF-8 locale already available: $locale_name"
			return 0
		fi
		echo "Locale is not available on macOS: $locale_name" >&2
		return 1
	fi

	if [[ "$os_id" != "ubuntu" && "$os_id" != "debian" && "$os_id" != "arch" ]]; then
		echo "Unsupported OS for locale setup: $os_id" >&2
		return 1
	fi

	if [[ ! -f "$locale_gen_file" ]]; then
		echo "$locale_gen_file not found; install the system locales package first" >&2
		return 1
	fi

	# Debian, Ubuntu, and Arch all use /etc/locale.gen. Keep the update
	# idempotent and leave any other explicitly enabled locales intact.
	if ! grep -Eq '^[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8([[:space:]]|$)' "$locale_gen_file"; then
		printf '\nen_US.UTF-8 UTF-8\n' | sudo tee -a "$locale_gen_file" >/dev/null
	fi

	sudo locale-gen

	if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
		# Passing a variable without a value removes it. Use LANG as the default
		# instead of category overrides that SSH may forward independently.
		sudo update-locale LANG="$locale_name" LC_ALL LC_CTYPE
	else
		if command -v localectl >/dev/null 2>&1 && sudo localectl set-locale LANG="$locale_name"; then
			:
		else
			# localectl may be unavailable in a chroot or container.
			if [[ -f /etc/locale.conf ]] && grep -q '^LANG=' /etc/locale.conf; then
				sudo sed -i "s/^LANG=.*/LANG=$locale_name/" /etc/locale.conf
			else
				printf 'LANG=%s\n' "$locale_name" | sudo tee -a /etc/locale.conf >/dev/null
			fi
		fi
		sudo sed -i -E '/^(LC_ALL|LC_CTYPE)=/d' /etc/locale.conf
	fi

	if ! LC_ALL="$locale_name" locale charmap 2>/dev/null | grep -qx "UTF-8"; then
		echo "Failed to generate UTF-8 locale: $locale_name" >&2
		return 1
	fi

	echo "UTF-8 locale configured: $locale_name"
}

# Allow this setup to be run directly as well as through ./install locale.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	if [[ -f /etc/os-release ]]; then
		os_id=$(grep -w ID /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
		[[ "$os_id" == "archarm" ]] && os_id="arch"
	else
		os_id=""
	fi
	setup_locale
fi
