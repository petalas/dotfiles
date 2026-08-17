#!/usr/bin/env bash
# Optional Debian and Arch mirror optimization helpers.

_linux_list_apt_sources() {
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"

    [[ ! -f "$apt_root/sources.list" ]] || printf '%s\n' "$apt_root/sources.list"
    if [[ -d "$apt_root/sources.list.d" ]]; then
        find "$apt_root/sources.list.d" -maxdepth 1 -type f \
            \( -name '*.list' -o -name '*.sources' \) -print | LC_ALL=C sort
    fi
}

_linux_debian_sources_contain() {
    local expected="$1"
    local source_file

    while IFS= read -r source_file; do
        [[ -n "$source_file" ]] || continue
        grep -Fq "$expected" "$source_file" && return 0
    done < <(_linux_list_apt_sources)
    return 1
}

_linux_backup_apt_source() {
    local source_file="$1"
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local backup_root="$apt_root/.dotfiles-backups"
    local relative_name backup_file

    relative_name="${source_file#"$apt_root"/}"
    backup_file="$backup_root/${relative_name//\//__}"
    [[ -e "$backup_file" ]] && return 0
    _linux_as_root mkdir -p "$backup_root"
    _linux_as_root cp -p "$source_file" "$backup_file"
}

_linux_escape_sed_pattern() {
    printf '%s' "$1" | sed 's/[][\\.^$*+?{}|()#]/\\&/g'
}

_linux_replace_debian_mirror() {
    local selected_mirror="${1%/}"
    local previous_mirror="${2%/}"
    local source_file work_file previous_pattern
    local -a sed_args

    sed_args=(
        -E
        -e "s#(https?://deb\\.debian\\.org/debian/?)([[:space:]]|$)#$selected_mirror\\2#g"
        -e "s#(https?://ftp(\\.[[:alnum:]-]+)?\\.debian\\.org/debian/?)([[:space:]]|$)#$selected_mirror\\3#g"
        -e "s#(https?://cdn-fastly\\.deb\\.debian\\.org/debian/?)([[:space:]]|$)#$selected_mirror\\2#g"
    )
    if [[ -n "$previous_mirror" ]]; then
        previous_pattern=$(_linux_escape_sed_pattern "$previous_mirror")
        sed_args+=(
            -e "s#(${previous_pattern}/?)([[:space:]]|$)#$selected_mirror\\2#g"
        )
    fi

    while IFS= read -r source_file; do
        [[ -n "$source_file" ]] || continue
        work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-source.XXXXXX")
        if ! sed "${sed_args[@]}" "$source_file" >"$work_file"; then
            rm -f "$work_file"
            return 1
        fi
        if _linux_files_differ "$source_file" "$work_file"; then
            if ! _linux_backup_apt_source "$source_file" ||
                ! _linux_install_root_file "$work_file" "$source_file"; then
                rm -f "$work_file"
                return 1
            fi
        fi
        rm -f "$work_file"
    done < <(_linux_list_apt_sources)
}

_linux_debian_release() {
    local release
    release=$(dotfiles_os_codename 2>/dev/null || true)
    printf '%s\n' "${release:-stable}"
}

_linux_debian_architecture() {
    local machine
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --print-architecture
        return
    fi
    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64) printf 'amd64\n' ;;
        arm64|aarch64) printf 'arm64\n' ;;
        *) printf '%s\n' "$machine" ;;
    esac
}

_linux_write_marker() {
    local value="$1"
    local destination="$2"
    local work_file

    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-marker.XXXXXX")
    printf '%s\n' "$value" >"$work_file"
    if ! _linux_install_root_file "$work_file" "$destination"; then
        rm -f "$work_file"
        return 1
    fi
    rm -f "$work_file"
}

_linux_optimize_debian_mirror() {
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local state_file="${DOTFILES_DEBIAN_MIRROR_STATE:-$apt_root/.dotfiles-fast-mirror}"
    local previous_mirror="" selected_mirror release architecture tests
    local work_dir generated_file

    if [[ -f "$state_file" ]]; then
        previous_mirror=$(head -n 1 "$state_file")
        if [[ -n "$previous_mirror" && "${DOTFILES_REFRESH_MIRRORS:-0}" != 1 ]] &&
            _linux_debian_sources_contain "$previous_mirror"; then
            echo "Debian mirror is already optimized: $previous_mirror"
            return 0
        fi
    fi

    command -v netselect-apt >/dev/null 2>&1 ||
        linux_packages_install netselect-apt || return 1

    release=$(_linux_debian_release)
    architecture=$(_linux_debian_architecture)
    tests="${DOTFILES_NETSELECT_TESTS:-20}"
    _require_positive_integer DOTFILES_NETSELECT_TESTS "$tests" || return 1
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-netselect.XXXXXX")
    generated_file="$work_dir/sources.list"
    if ! netselect-apt -a "$architecture" -t "$tests" -n \
        -o "$generated_file" "$release"; then
        rm -rf "$work_dir"
        return 1
    fi
    selected_mirror=$(awk '$1 == "deb" && $2 ~ /\/debian\/?$/ { print $2; exit }' "$generated_file")
    rm -rf "$work_dir"
    [[ -n "$selected_mirror" ]] || {
        echo "netselect-apt did not return a Debian archive mirror." >&2
        return 1
    }
    selected_mirror="${selected_mirror%/}"

    _linux_replace_debian_mirror "$selected_mirror" "$previous_mirror" || return 1
    linux_packages_refresh || return 1
    _linux_write_marker "$selected_mirror" "$state_file" || return 1
    echo "Configured fastest Debian mirror: $selected_mirror"
}

_linux_optimize_arch_mirror() {
    local mirrorlist="${DOTFILES_PACMAN_MIRRORLIST:-/etc/pacman.d/mirrorlist}"
    local state_file="${DOTFILES_PACMAN_MIRROR_STATE:-/etc/pacman.d/.dotfiles-reflector}"
    local work_file all_mirrors

    if [[ "${DOTFILES_REFRESH_MIRRORS:-0}" != 1 && -f "$state_file" && -s "$mirrorlist" ]]; then
        echo "Arch mirror list is already optimized."
        return 0
    fi
    [[ -f "$mirrorlist" ]] || {
        echo "Pacman mirror list not found: $mirrorlist" >&2
        return 1
    }

    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-mirrorlist.XXXXXX")
    if [[ "$(dotfiles_os_raw)" == archarm ]]; then
        command -v rankmirrors >/dev/null 2>&1 ||
            linux_packages_install pacman-contrib || { rm -f "$work_file"; return 1; }
        all_mirrors=$(mktemp "${TMPDIR:-/tmp}/dotfiles-mirrorlist-all.XXXXXX")
        sed 's/^[[:space:]]*#Server/Server/' "$mirrorlist" >"$all_mirrors"
        if ! rankmirrors -n 20 "$all_mirrors" >"$work_file"; then
            rm -f "$work_file" "$all_mirrors"
            return 1
        fi
        rm -f "$all_mirrors"
    else
        command -v reflector >/dev/null 2>&1 ||
            linux_packages_install reflector || { rm -f "$work_file"; return 1; }
        if ! reflector --protocol https --latest 100 --sort rate --number 20 \
            --threads 16 --save "$work_file"; then
            rm -f "$work_file"
            return 1
        fi
    fi

    grep -q '^[[:space:]]*Server[[:space:]]*=' "$work_file" || {
        rm -f "$work_file"
        echo "Mirror ranking returned an empty pacman mirror list." >&2
        return 1
    }
    if [[ ! -e "$mirrorlist.dotfiles-backup" ]] &&
        ! _linux_as_root cp -p "$mirrorlist" "$mirrorlist.dotfiles-backup"; then
        rm -f "$work_file"
        return 1
    fi
    if ! _linux_install_root_file "$work_file" "$mirrorlist"; then
        rm -f "$work_file"
        return 1
    fi
    rm -f "$work_file"
    _linux_write_marker "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$state_file" || return 1
    echo "Configured the fastest Arch mirrors."
}

linux_packages_optimize_mirrors() {
    local distribution
    distribution=$(linux_distribution)
    linux_packages_prepare || return 1

    case "$distribution" in
        debian) _linux_optimize_debian_mirror ;;
        ubuntu) return 0 ;;
        arch) _linux_optimize_arch_mirror ;;
        *) return 1 ;;
    esac
}
