#!/usr/bin/env bash

setup_zsh() {
    local current_shell os zsh_path user
    os=$(dotfiles_os) || return 1
    user=$(dotfiles_target_user)

    if ! command -v zsh >/dev/null 2>&1; then
        case "$os" in
            ubuntu|debian|arch)
                linux_packages_install zsh
                ;;
            macos)
                brew install zsh
                ;;
            *)
                echo "Unsupported OS for Zsh setup: $os" >&2
                return 1
                ;;
        esac
    fi

    zsh_path=$(command -v zsh)
    if ! grep -Fqx "$zsh_path" /etc/shells; then
        echo "Zsh is not listed in /etc/shells: $zsh_path" >&2
        return 1
    fi

    if ! current_shell=$(dotfiles_login_shell "$user"); then
        echo "Could not determine $user's login shell." >&2
        return 1
    fi
    if [[ "$current_shell" == "$zsh_path" ]]; then
        echo "Zsh is already the login shell."
        return 0
    fi

    echo "Changing $user's login shell to $zsh_path."
    run_as_root chsh -s "$zsh_path" "$user"
    if ! current_shell=$(dotfiles_login_shell "$user") || [[ "$current_shell" != "$zsh_path" ]]; then
        echo "The login shell change for $user did not take effect." >&2
        return 1
    fi
}
