#!/usr/bin/env bash
# shellcheck disable=SC2154

install_docker() {
    local user
    local -a packages

    if ! command -v docker >/dev/null 2>&1; then
        case "$os_id" in
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
        sudo -n systemctl enable --now docker || return 1
    fi
    user=$(id -un)
    if getent group docker >/dev/null 2>&1; then
        sudo -n usermod -aG docker "$user" || return 1
    fi
    echo "Docker is installed. Log out and back in for group access."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install docker" >&2
    exit 2
fi
