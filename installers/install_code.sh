#!/usr/bin/env bash

install_code() {
    local key_asc key_gpg os source_file work_dir
    command -v code >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1

    case "$os" in
        ubuntu|debian)
            echo "Installing Visual Studio Code from its APT repository..."
            work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-code.XXXXXX") || return 1
            key_asc="$work_dir/microsoft.asc"
            key_gpg="$work_dir/microsoft.gpg"
            source_file="$work_dir/vscode.list"
            if ! download_file https://packages.microsoft.com/keys/microsoft.asc "$key_asc" ||
                ! verify_key_fingerprint "$key_asc" BC528686B50D79E339D3721CEB3E94ADBE1229CF ||
                ! gpg --dearmor <"$key_asc" >"$key_gpg"; then
                rm -rf "$work_dir"
                return 1
            fi
            printf '%s\n' \
                'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' \
                >"$source_file"
            if ! _linux_install_root_file "$key_gpg" /etc/apt/keyrings/packages.microsoft.gpg ||
                ! _linux_install_root_file "$source_file" /etc/apt/sources.list.d/vscode.list; then
                rm -rf "$work_dir"
                return 1
            fi
            rm -rf "$work_dir"
            linux_packages_refresh
            linux_packages_install code
            ;;
        arch) linux_packages_install code ;;
        *) return 1 ;;
    esac
}
