#!/usr/bin/env bash

install_lazygit() {
    local asset version arch work_dir os
    command -v lazygit >/dev/null 2>&1 && return 0
    os=$(dotfiles_os) || return 1

    if [[ "$os" == arch ]] || linux_package_available lazygit; then
        linux_packages_install lazygit
        return
    fi
    [[ "$os" == ubuntu || "$os" == debian ]] || return 1

    # Ubuntu releases without a lazygit package use the upstream native binary.
    version=$(github_latest_tag jesseduffield/lazygit)
    version=${version#v}
    case "$(uname -m)" in
        x86_64|amd64) arch=x86_64 ;;
        arm64|aarch64) arch=arm64 ;;
        *) return 1 ;;
    esac
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lazygit.XXXXXX")
    asset="lazygit_${version}_Linux_$arch.tar.gz"
    if ! download_file \
        "https://github.com/jesseduffield/lazygit/releases/download/v$version/$asset" \
        "$work_dir/$asset" ||
        ! verify_sha256_manifest "$work_dir/$asset" \
            "https://github.com/jesseduffield/lazygit/releases/download/v$version/checksums.txt" \
            "$asset" ||
        ! tar -xzf "$work_dir/$asset" -C "$work_dir"; then
        rm -rf "$work_dir"
        return 1
    fi
    if ! run_as_root install -m 0755 "$work_dir/lazygit" /usr/local/bin/lazygit; then
        rm -rf "$work_dir"
        return 1
    fi
    rm -rf "$work_dir"
}
