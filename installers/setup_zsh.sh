#!/usr/bin/env bash
# shellcheck disable=SC2154

setup_zsh() {
    local zsh_path user
    user=$(whoami)

    if ! command -v zsh >/dev/null 2>&1; then
        case "${os_id:-}" in
            ubuntu|debian|arch)
                linux_packages_install zsh
                ;;
            macos)
                brew install zsh
                ;;
            *)
                echo "Unsupported OS for Zsh setup: ${os_id:-unknown}" >&2
                return 1
                ;;
        esac
    fi

    zsh_path=$(command -v zsh)
    if [[ "${DOTFILES_INTEGRATION_TEST:-0}" == 1 ]]; then
        echo "Zsh is installed; skipping the login-shell change in the container."
        return 0
    fi
    if [[ "${SHELL:-}" == "$zsh_path" ]]; then
        echo "Zsh is already the login shell."
        return 0
    fi

    echo "Changing $user's login shell to $zsh_path."
    sudo -n chsh -s "$zsh_path" "$user"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this setup through: ./install zsh" >&2
    exit 2
fi
