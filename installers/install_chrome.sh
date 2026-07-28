#!/usr/bin/env bash
# shellcheck disable=SC2154

install_chrome() {
    if command -v google-chrome >/dev/null 2>&1 ||
        command -v google-chrome-stable >/dev/null 2>&1 ||
        { [[ "$os_id" == arch ]] && command -v chromium >/dev/null 2>&1; }; then
        return 0
    fi

    case "$os_id" in
        ubuntu|debian)
            [[ "$(uname -m)" == x86_64 ]] || {
                echo "Google Chrome only publishes an amd64 Linux package." >&2
                return 1
            }
            echo "Installing ${yellow}Google Chrome${reset} from its APT repository..."
            curl -fsSL https://dl.google.com/linux/linux_signing_key.pub |
                gpg --dearmor |
                sudo -n tee /usr/share/keyrings/google-chrome.gpg >/dev/null
            printf '%s\n' \
                'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main' |
                sudo -n tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
            linux_packages_refresh
            linux_packages_install google-chrome-stable
            ;;
        arch) linux_packages_install chromium ;;
        *) return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install chrome" >&2
    exit 2
fi
