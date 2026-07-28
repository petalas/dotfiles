#!/usr/bin/env bash
# shellcheck disable=SC2154

install_lazygit() {
    local version arch work_dir
    command -v lazygit >/dev/null 2>&1 && return 0

    if [[ "$os_id" == arch ]] || linux_package_available lazygit; then
        linux_packages_install lazygit
        return
    fi
    [[ "$os_id" == ubuntu || "$os_id" == debian ]] || return 1

    # Ubuntu releases without a lazygit package use the upstream native binary.
    version=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
        jq -r '.tag_name | ltrimstr("v")')
    case "$(uname -m)" in
        x86_64|amd64) arch=x86_64 ;;
        arm64|aarch64) arch=arm64 ;;
        *) return 1 ;;
    esac
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lazygit.XXXXXX")
    if ! curl -fL --retry 3 \
        "https://github.com/jesseduffield/lazygit/releases/download/v$version/lazygit_${version}_Linux_$arch.tar.gz" \
        -o "$work_dir/lazygit.tar.gz" ||
        ! tar -xzf "$work_dir/lazygit.tar.gz" -C "$work_dir"; then
        rm -rf "$work_dir"
        return 1
    fi
    sudo -n install -m 0755 "$work_dir/lazygit" /usr/local/bin/lazygit
    rm -rf "$work_dir"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install lazygit" >&2
    exit 2
fi
