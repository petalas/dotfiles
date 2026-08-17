#!/usr/bin/env bash

install_chrome() {
    local key_asc key_gpg os source_file work_dir

    os=$(dotfiles_os) || return 1
    if command -v google-chrome >/dev/null 2>&1 ||
        command -v google-chrome-stable >/dev/null 2>&1 ||
        { [[ "$os" == arch ]] && command -v chromium >/dev/null 2>&1; }; then
        return 0
    fi

    case "$os" in
        ubuntu|debian)
            [[ "$(uname -m)" == x86_64 ]] || {
                echo "Google Chrome only publishes an amd64 Linux package." >&2
                return 1
            }
            echo "Installing Google Chrome from its APT repository..."
            work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-chrome.XXXXXX") || return 1
            key_asc="$work_dir/google.asc"
            key_gpg="$work_dir/google.gpg"
            source_file="$work_dir/google-chrome.list"
            if ! download_file https://dl.google.com/linux/linux_signing_key.pub "$key_asc" ||
                ! verify_key_fingerprint "$key_asc" EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796 ||
                ! gpg --dearmor <"$key_asc" >"$key_gpg"; then
                rm -rf "$work_dir"
                return 1
            fi
            printf '%s\n' \
                'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main' \
                >"$source_file"
            if ! _linux_install_root_file "$key_gpg" /usr/share/keyrings/google-chrome.gpg ||
                ! _linux_install_root_file "$source_file" /etc/apt/sources.list.d/google-chrome.list; then
                rm -rf "$work_dir"
                return 1
            fi
            rm -rf "$work_dir"
            linux_packages_refresh
            linux_packages_install google-chrome-stable
            ;;
        arch) linux_packages_install chromium ;;
        *) return 1 ;;
    esac
}
