#!/usr/bin/env bash
# Arch Linux pacman helpers.

_linux_configure_pacman() {
    local config_file="${DOTFILES_PACMAN_CONF:-/etc/pacman.conf}"
    local downloads="${DOTFILES_PACMAN_PARALLEL_DOWNLOADS:-8}"
    local work_file

    _require_positive_integer DOTFILES_PACMAN_PARALLEL_DOWNLOADS "$downloads" || return 1
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

    if _linux_files_differ "$config_file" "$work_file" &&
        ! _linux_install_root_file "$work_file" "$config_file"; then
        rm -f "$work_file"
        return 1
    fi
    rm -f "$work_file"
}

