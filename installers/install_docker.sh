#!/usr/bin/env bash

install_docker() {
    local os user
    local -a packages

    os=$(dotfiles_os) || return 1
    if ! command -v docker >/dev/null 2>&1; then
        case "$os" in
            ubuntu|debian)
                packages=(docker.io)
                if linux_package_available docker-compose-v2; then
                    packages+=(docker-compose-v2)
                elif linux_package_available docker-compose; then
                    packages+=(docker-compose)
                fi
                linux_package_available docker-buildx && packages+=(docker-buildx)
                linux_packages_install "${packages[@]}"
                ;;
            arch)
                linux_packages_install docker docker-compose docker-buildx
                ;;
            *) return 1 ;;
        esac
    fi

    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        run_as_root systemctl enable --now docker || return 1
    fi
    user=$(id -un)
    if getent group docker >/dev/null 2>&1; then
        run_as_root usermod -aG docker "$user" || return 1
    fi
    echo "Docker is installed. Log out and back in for group access."
}
