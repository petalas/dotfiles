#!/usr/bin/env bash
# shellcheck disable=SC2154

install_code() {
    local key_file
    command -v code >/dev/null 2>&1 && return 0

    case "$os_id" in
        ubuntu|debian)
            echo "Installing ${yellow}Visual Studio Code${reset} from its APT repository..."
            key_file=$(mktemp "${TMPDIR:-/tmp}/packages-microsoft.XXXXXX.gpg")
            if ! curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
                gpg --dearmor >"$key_file"; then
                rm -f "$key_file"
                return 1
            fi
            sudo -n install -D -o root -g root -m 0644 \
                "$key_file" /etc/apt/keyrings/packages.microsoft.gpg
            rm -f "$key_file"
            printf '%s\n' \
                'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' |
                sudo -n tee /etc/apt/sources.list.d/vscode.list >/dev/null
            linux_packages_refresh
            linux_packages_install code
            ;;
        arch) linux_packages_install code ;;
        *) return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install code" >&2
    exit 2
fi
