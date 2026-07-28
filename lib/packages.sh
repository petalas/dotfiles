#!/usr/bin/env bash
# Linux package-manager and mirror helpers shared by setup scripts and zsh.

if [[ "${_DOTFILES_LINUX_PACKAGES_LOADED:-0}" == 1 ]]; then
    return 0
fi
_DOTFILES_LINUX_PACKAGES_LOADED=1

linux_distribution() {
    local distribution="${os_id:-}"

    if [[ -z "$distribution" && -r /etc/os-release ]]; then
        distribution=$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release)
    fi
    [[ "$distribution" != archarm ]] || distribution=arch
    printf '%s\n' "$distribution"
}

_linux_as_root() {
    if [[ "${DOTFILES_PACKAGE_NO_SUDO:-0}" == 1 || "${EUID:-$(id -u)}" == 0 ]]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

_linux_install_root_file() {
    local source_file="$1"
    local destination="$2"
    local mode="${3:-0644}"

    _linux_as_root mkdir -p "$(dirname "$destination")"
    _linux_as_root install -m "$mode" "$source_file" "$destination"
}

_linux_files_differ() {
    if command -v cmp >/dev/null 2>&1; then
        ! cmp -s "$1" "$2"
    else
        [[ "$(cksum <"$1")" != "$(cksum <"$2")" ]]
    fi
}

_run_batch_with_retries() {
    local callback="$1"
    shift
    local attempts="${DOTFILES_BATCH_RETRIES:-3}"
    local delay_seconds="${DOTFILES_BATCH_RETRY_DELAY_SECONDS:-2}"
    local attempt=1

    while ((attempt <= attempts)); do
        "$callback" "$@" && return 0
        if ((attempt < attempts)); then
            printf 'Package batch failed (attempt %d/%d); retrying: %s\n' \
                "$attempt" "$attempts" "$*" >&2
            sleep "$((delay_seconds * attempt))"
        fi
        ((attempt += 1))
    done
    return 1
}

_run_resilient_batch_group() {
    local callback="$1"
    shift
    local item item_index=0 split_at=$((($# + 1) / 2))
    local group_failed=0
    local -a left=() right=()

    if _run_batch_with_retries "$callback" "$@"; then
        return 0
    fi
    if (($# == 1)); then
        _dotfiles_failed_batch_items+=("$1")
        return 1
    fi

    for item in "$@"; do
        ((item_index += 1))
        if ((item_index <= split_at)); then
            left+=("$item")
        else
            right+=("$item")
        fi
    done
    _run_resilient_batch_group "$callback" "${left[@]}" || group_failed=1
    _run_resilient_batch_group "$callback" "${right[@]}" || group_failed=1
    return "$group_failed"
}

run_resilient_batch() {
    local label="$1"
    local callback="$2"
    shift 2
    local batch_result=0
    local IFS=', '

    (($#)) || return 0
    _dotfiles_failed_batch_items=()
    _run_resilient_batch_group "$callback" "$@" || batch_result=1
    if ((${#_dotfiles_failed_batch_items[@]})); then
        printf 'Failed %s after retries: %s\n' \
            "$label" "${_dotfiles_failed_batch_items[*]}" >&2
    fi
    return "$batch_result"
}

_linux_apt_get() {
    _linux_as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
        apt-get "$@"
}

_linux_preseed_apt_fast() {
    local connections="${DOTFILES_APT_PARALLEL_DOWNLOADS:-8}"

    command -v debconf-set-selections >/dev/null 2>&1 || return 1
    printf '%s\n' \
        "debconf apt-fast/maxdownloads string $connections" \
        'debconf apt-fast/dlflag boolean true' \
        'debconf apt-fast/aptmanager string apt-get' |
        _linux_as_root debconf-set-selections
}

_linux_install_apt_fast_prerequisites() {
    local -a packages=()

    command -v curl >/dev/null 2>&1 || packages+=(ca-certificates curl)
    command -v gpg >/dev/null 2>&1 || packages+=(gnupg)
    command -v debconf-set-selections >/dev/null 2>&1 || packages+=(debconf)
    ((${#packages[@]} == 0)) && return 0

    _linux_apt_get update && _linux_apt_get install -y "${packages[@]}"
}

_linux_write_apt_fast_source() {
    local suite="$1"
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local key_file="${DOTFILES_APT_FAST_KEYRING:-$apt_root/keyrings/apt-fast.gpg}"
    local source_file="${DOTFILES_APT_FAST_SOURCE:-$apt_root/sources.list.d/apt-fast.sources}"
    local work_file

    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-fast-source.XXXXXX")
    cat >"$work_file" <<EOF
Types: deb
URIs: ${DOTFILES_APT_FAST_PPA_URI:-https://ppa.launchpadcontent.net/apt-fast/stable/ubuntu/}
Suites: $suite
Components: main
Signed-By: $key_file
EOF
    _linux_install_root_file "$work_file" "$source_file"
    rm -f "$work_file"
}

_linux_install_apt_fast_key() {
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local key_file="${DOTFILES_APT_FAST_KEYRING:-$apt_root/keyrings/apt-fast.gpg}"
    local work_file

    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-fast-key.XXXXXX")
    if ! curl -fsSL \
        'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBC5934FD3DEBD4DAEA544F791E2824A7F22B44BD' |
        gpg --dearmor >"$work_file" || [[ ! -s "$work_file" ]]; then
        rm -f "$work_file"
        return 1
    fi
    _linux_install_root_file "$work_file" "$key_file"
    rm -f "$work_file"
}

_linux_install_apt_fast() {
    local distribution current_suite suite tried_suites="" repository_ready=0
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local source_file="${DOTFILES_APT_FAST_SOURCE:-$apt_root/sources.list.d/apt-fast.sources}"
    local -a suites=()

    _linux_install_apt_fast_prerequisites || return 1
    _linux_install_apt_fast_key || return 1

    distribution=$(linux_distribution)
    if [[ -n "${DOTFILES_APT_FAST_SUITE:-}" ]]; then
        suites=("$DOTFILES_APT_FAST_SUITE")
    elif [[ "$distribution" == ubuntu ]]; then
        current_suite=$(_linux_debian_release)
        suites=("$current_suite" jammy focal)
    else
        suites=(jammy focal)
    fi

    for suite in "${suites[@]}"; do
        [[ -n "$suite" && " $tried_suites " != *" $suite "* ]] || continue
        tried_suites="$tried_suites $suite"
        _linux_write_apt_fast_source "$suite" || continue
        if _linux_apt_get update; then
            repository_ready=1
            break
        fi
    done
    if ((repository_ready == 0)); then
        _linux_as_root rm -f "$source_file"
        _linux_apt_get update || true
        return 1
    fi

    _linux_preseed_apt_fast || return 1
    _linux_apt_get install -y apt-fast aria2 || return 1
    command -v apt-fast >/dev/null 2>&1
}

_linux_configure_apt_fast() {
    local config_file="${DOTFILES_APT_FAST_CONFIG:-/etc/apt-fast.conf}"
    local connections="${DOTFILES_APT_PARALLEL_DOWNLOADS:-8}"
    local work_file

    [[ -f "$config_file" ]] || return 0
    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-apt-fast.XXXXXX")
    awk -v connections="$connections" '
        BEGIN { maxnum = 0; per_server = 0 }
        /^[[:space:]]*#?[[:space:]]*_MAXNUM=/ {
            if (!maxnum++) print "_MAXNUM=" connections
            next
        }
        /^[[:space:]]*#?[[:space:]]*_MAXCONPERSRV=/ {
            if (!per_server++) print "_MAXCONPERSRV=" connections
            next
        }
        { print }
        END {
            if (!maxnum) print "_MAXNUM=" connections
            if (!per_server) print "_MAXCONPERSRV=" connections
        }
    ' "$config_file" >"$work_file"

    if _linux_files_differ "$config_file" "$work_file"; then
        _linux_install_root_file "$work_file" "$config_file"
    fi
    rm -f "$work_file"
}

_linux_bootstrap_apt_frontend() {
    local frontend=""

    if command -v apt-fast >/dev/null 2>&1; then
        _linux_preseed_apt_fast || return 1
        frontend=apt-fast
    elif _linux_install_apt_fast; then
        frontend=apt-fast
    elif command -v nala >/dev/null 2>&1; then
        frontend=nala
    else
        echo "Warning: apt-fast setup failed; trying Nala from the distro repository." >&2
        _linux_apt_get update || true
        if apt-cache show nala >/dev/null 2>&1; then
            _linux_apt_get install -y nala || true
            command -v nala >/dev/null 2>&1 && frontend=nala
        fi
    fi

    if [[ -z "$frontend" ]]; then
        echo "Warning: no parallel APT frontend is available; using apt-get." >&2
        frontend=apt-get
    fi
    _dotfiles_apt_frontend="$frontend"
    [[ "$frontend" != apt-fast ]] || _linux_configure_apt_fast
}

_linux_configure_pacman() {
    local config_file="${DOTFILES_PACMAN_CONF:-/etc/pacman.conf}"
    local downloads="${DOTFILES_PACMAN_PARALLEL_DOWNLOADS:-8}"
    local work_file

    case "$downloads" in
        ''|*[!0-9]*)
            echo "Invalid pacman parallel-download count: $downloads" >&2
            return 1
            ;;
    esac
    ((downloads > 0)) || {
        echo "Pacman parallel-download count must be positive." >&2
        return 1
    }
    [[ -f "$config_file" ]] || {
        echo "Pacman configuration not found: $config_file" >&2
        return 1
    }

    work_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-pacman.XXXXXX")
    if grep -Eq '^[[:space:]]*#?[[:space:]]*ParallelDownloads[[:space:]]*=' "$config_file"; then
        awk -v downloads="$downloads" '
            BEGIN { replaced = 0 }
            /^[[:space:]]*#?[[:space:]]*ParallelDownloads[[:space:]]*=/ {
                if (!replaced++) print "ParallelDownloads = " downloads
                next
            }
            { print }
        ' "$config_file" >"$work_file"
    else
        awk -v downloads="$downloads" '
            { print }
            !added && $0 == "[options]" {
                print "ParallelDownloads = " downloads
                added = 1
            }
            END { if (!added) exit 1 }
        ' "$config_file" >"$work_file" || {
            rm -f "$work_file"
            echo "Pacman [options] section not found in $config_file" >&2
            return 1
        }
    fi

    if _linux_files_differ "$config_file" "$work_file"; then
        _linux_install_root_file "$work_file" "$config_file"
    fi
    rm -f "$work_file"
}

linux_packages_prepare() {
    local distribution
    distribution=$(linux_distribution)

    [[ "${_dotfiles_packages_prepared_for:-}" != "$distribution" ]] || return 0
    case "$distribution" in
        debian|ubuntu)
            if ! command -v apt-fast >/dev/null 2>&1 &&
                ! command -v nala >/dev/null 2>&1 &&
                ! command -v apt-get >/dev/null 2>&1; then
                echo "apt-get is required to bootstrap Debian packages." >&2
                return 1
            fi
            _linux_bootstrap_apt_frontend
            ;;
        arch)
            command -v pacman >/dev/null 2>&1 || {
                echo "pacman is required on Arch Linux." >&2
                return 1
            }
            _linux_configure_pacman
            ;;
        *)
            echo "Unsupported Linux distribution: ${distribution:-unknown}" >&2
            return 1
            ;;
    esac
    _dotfiles_packages_prepared_for="$distribution"
}

_linux_apt_run() {
    _linux_as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
        "$_dotfiles_apt_frontend" "$@"
}

_linux_pacman_run() {
    _linux_as_root pacman "$@"
}

linux_packages_refresh() {
    local distribution
    distribution=$(linux_distribution)
    linux_packages_prepare || return 1
    case "$distribution" in
        debian|ubuntu) _linux_apt_run update ;;
        arch) _linux_pacman_run -Syu --noconfirm ;;
    esac
}

_linux_packages_install_once() {
    case "$(linux_distribution)" in
        debian|ubuntu) _linux_apt_run install -y "$@" ;;
        arch) _linux_pacman_run -Syu --noconfirm --needed "$@" ;;
    esac
}

linux_packages_install() {
    (($#)) || return 0
    linux_packages_prepare || return 1
    run_resilient_batch 'distro packages' _linux_packages_install_once "$@"
}

linux_packages_upgrade() {
    local distribution
    distribution=$(linux_distribution)
    linux_packages_prepare || return 1
    case "$distribution" in
        debian|ubuntu)
            _linux_apt_run update &&
                _linux_apt_run upgrade -y &&
                _linux_apt_run autoremove -y
            ;;
        arch)
            _linux_pacman_run -Syu --noconfirm
            ;;
    esac
}

linux_package_available() {
    local package="$1"
    case "$(linux_distribution)" in
        debian|ubuntu) apt-cache show "$package" >/dev/null 2>&1 ;;
        arch) pacman -Si "$package" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

linux_packages_install_available() {
    local package
    local -a available_packages=()

    for package in "$@"; do
        if linux_package_available "$package"; then
            available_packages+=("$package")
        else
            printf 'Skipping unavailable distro package: %s\n' "$package" >&2
        fi
    done
    ((${#available_packages[@]} == 0)) || linux_packages_install "${available_packages[@]}"
}

linux_install_deb_url() {
    local url="$1"
    local package_name="${2:-package}"
    local work_dir package_file
    local install_result=0

    case "$(linux_distribution)" in
        debian|ubuntu) ;;
        *) return 1 ;;
    esac
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-deb.XXXXXX")
    package_file="$work_dir/$package_name.deb"
    if ! curl -fL --retry 3 "$url" -o "$package_file"; then
        rm -rf "$work_dir"
        return 1
    fi
    linux_packages_install "$package_file" || install_result=$?
    rm -rf "$work_dir"
    return "$install_result"
}

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
            _linux_backup_apt_source "$source_file"
            _linux_install_root_file "$work_file" "$source_file"
        fi
        rm -f "$work_file"
    done < <(_linux_list_apt_sources)
}

_linux_debian_release() {
    local release="${os_version_codename:-}"

    if [[ -z "$release" && -r /etc/os-release ]]; then
        release=$(awk -F= '$1 == "VERSION_CODENAME" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release)
    fi
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
    _linux_install_root_file "$work_file" "$destination"
    rm -f "$work_file"
}

_linux_optimize_debian_mirror() {
    local apt_root="${DOTFILES_APT_ROOT:-/etc/apt}"
    local state_file="${DOTFILES_DEBIAN_MIRROR_STATE:-$apt_root/.dotfiles-fast-mirror}"
    local previous_mirror="" selected_mirror release architecture tests
    local work_dir generated_file

    if [[ -f "$state_file" ]]; then
        previous_mirror=$(head -n 1 "$state_file")
        if [[ "${DOTFILES_REFRESH_MIRRORS:-0}" != 1 ]] &&
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
    _linux_write_marker "$selected_mirror" "$state_file"
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
    if [[ "${os_id_raw:-arch}" == archarm ]]; then
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
    if [[ ! -e "$mirrorlist.dotfiles-backup" ]]; then
        _linux_as_root cp -p "$mirrorlist" "$mirrorlist.dotfiles-backup"
    fi
    _linux_install_root_file "$work_file" "$mirrorlist"
    rm -f "$work_file"
    _linux_write_marker "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$state_file"
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
