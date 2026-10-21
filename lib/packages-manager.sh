#!/usr/bin/env bash
# Public package-manager operations shared by setup and Zsh.

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
            _linux_bootstrap_apt_frontend || return 1
            ;;
        arch)
            command -v pacman >/dev/null 2>&1 || {
                echo "pacman is required on Arch Linux." >&2
                return 1
            }
            _linux_configure_pacman || return 1
            ;;
        *)
            echo "Unsupported Linux distribution: ${distribution:-unknown}" >&2
            return 1
            ;;
    esac
    _dotfiles_packages_prepared_for="$distribution"
}

_linux_apt_run() {
    local frontend="${_dotfiles_apt_frontend:-}"
    [[ -n "$frontend" ]] || {
        echo "APT frontend has not been prepared." >&2
        return 1
    }
    _linux_as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
        "$frontend" "$@"
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
        arch) _linux_pacman_run -S --noconfirm --needed "$@" ;;
    esac
}

linux_packages_install() {
    local package
    (($#)) || return 0
    linux_packages_prepare || return 1
    case "$(linux_distribution)" in
        debian|ubuntu)
            for package in "$@"; do
                [[ "$package" == gh ]] || continue
                linux_github_cli_prepare_repository && _linux_apt_run update || return 1
                break
            done
            ;;
    esac
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

# Print "name<TAB>version<TAB>listed" for each installed system package, where
# listed is 1 for packages installed explicitly rather than as dependencies.
linux_packages_versions() {
    local explicit installed
    case "$(linux_distribution)" in
        debian|ubuntu)
            explicit=$(apt-mark showmanual) || return 1
            installed=$(dpkg-query -W -f='${db:Status-Abbrev}\t${Package}\t${Version}\n') || return 1
            installed=$(printf '%s\n' "$installed" | awk -F '\t' -v OFS='\t' '$1 ~ /^ii/ { print $2, $3 }')
            ;;
        arch)
            explicit=$(pacman -Qqe) || return 1
            installed=$(pacman -Q) || return 1
            installed=$(printf '%s\n' "$installed" | awk -v OFS='\t' 'NF == 2 { print $1, $2 }')
            ;;
        *) return 1 ;;
    esac
    { printf '%s\n' "$explicit" '--installed--' "$installed"; } | awk -F '\t' -v OFS='\t' '
        $0 == "--installed--" { section = 1; next }
        !section { if ($1 != "") explicit[$1] = 1; next }
        $1 != "" { print $1, $2, (explicit[$1] ? 1 : 0) }
    '
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
    if ! download_file "$url" "$package_file"; then
        rm -rf "$work_dir"
        return 1
    fi
    linux_packages_install "$package_file" || install_result=$?
    rm -rf "$work_dir"
    return "$install_result"
}

