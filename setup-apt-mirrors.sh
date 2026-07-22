#!/usr/bin/env bash
set -euo pipefail

apt_root="${APT_SOURCES_ROOT:-/etc/apt}"
os_id="${APT_MIRROR_OS_ID:-}"

if [[ -z "$os_id" && -f /etc/os-release ]]; then
	os_id=$(grep -w ID /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
fi

case "$os_id" in
	debian|ubuntu) ;;
	*) exit 0 ;;
esac

run_as_root() {
	if [[ -n "${APT_SOURCES_ROOT:-}" || $EUID -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

declare -a source_files=()
[[ -f "$apt_root/sources.list" ]] && source_files+=("$apt_root/sources.list")

shopt -s nullglob
source_files+=("$apt_root"/sources.list.d/*.list)
source_files+=("$apt_root"/sources.list.d/*.sources)
shopt -u nullglob

if [[ ${#source_files[@]} -eq 0 ]]; then
	echo "No APT sources found under $apt_root; skipping mirror configuration."
	exit 0
fi

backup_dir="${APT_MIRROR_BACKUP_DIR:-$apt_root/.dotfiles-backups}"
changed_count=0
ubuntu_primary_mirror="${APT_PRIMARY_MIRROR:-mirror+http://mirrors.ubuntu.com/mirrors.txt}"
ubuntu_primary_mirror="${ubuntu_primary_mirror%/}"
ubuntu_security_mirror="${APT_SECURITY_MIRROR:-}"
ubuntu_security_mirror="${ubuntu_security_mirror%/}"
ubuntu_source_pattern='https?://([[:alnum:]-]+\.)?archive\.ubuntu\.com/ubuntu/?'
ubuntu_rewrite_args=(
	-e "s#https?://([[:alnum:]-]+\.)?archive\\.ubuntu\\.com/ubuntu/?#$ubuntu_primary_mirror#g"
)
if [[ -n "$ubuntu_security_mirror" ]]; then
	ubuntu_source_pattern+='|https?://security\.ubuntu\.com/ubuntu/?'
	ubuntu_rewrite_args+=(
		-e "s#https?://security\\.ubuntu\\.com/ubuntu/?#$ubuntu_security_mirror#g"
	)
fi

backup_source() {
	local source_file="$1"
	local relative_name backup_name

	relative_name="${source_file#"$apt_root"/}"
	backup_name="${relative_name//\//__}"
	run_as_root mkdir -p "$backup_dir"
	if [[ ! -e "$backup_dir/$backup_name" ]]; then
		run_as_root cp -p "$source_file" "$backup_dir/$backup_name"
	fi
}

rewrite_source() {
	local source_file="$1"
	local work_dir
	shift

	work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-apt-source.XXXXXX")
	if sed -E "$@" "$source_file" >"$work_dir/source" &&
		run_as_root cp "$work_dir/source" "$source_file"; then
		rm -r -- "$work_dir"
		return 0
	fi

	rm -r -- "$work_dir"
	return 1
}

for source_file in "${source_files[@]}"; do
	case "$os_id" in
		debian)
			# deb.debian.org is Debian's official CDN and automatically routes
			# requests to a nearby edge. Replace only legacy Debian-owned hosts;
			# preserve deliberately configured third-party or local mirrors.
			if grep -Eq 'https?://(ftp(\.[[:alnum:]-]+)?\.debian\.org/debian|security\.debian\.org/debian-security)/?' "$source_file"; then
				backup_source "$source_file"
				rewrite_source "$source_file" \
					-e 's#https?://ftp(\.[[:alnum:]-]+)?\.debian\.org/debian/?#http://deb.debian.org/debian#g' \
					-e 's#https?://security\.debian\.org/debian-security/?#http://deb.debian.org/debian-security#g'
				((changed_count += 1))
			fi
			;;
		ubuntu)
			# Canonical's mirror index is generated from the requester IP and
			# returns nearby, current official mirrors. APT's mirror transport
			# transparently falls back to another entry when one is unavailable.
			# Keep security.ubuntu.com unchanged unless the caller supplies a
			# separate security override explicitly.
			if grep -Eq "$ubuntu_source_pattern" "$source_file"; then
				backup_source "$source_file"
				rewrite_source "$source_file" "${ubuntu_rewrite_args[@]}"
				((changed_count += 1))
			fi
			;;
	esac
done

if [[ $changed_count -eq 0 ]]; then
	echo "$os_id APT sources already use the preferred mirror service."
else
	echo "Configured $changed_count $os_id APT source file(s) to use the preferred mirror service."
fi
