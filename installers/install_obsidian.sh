#!/usr/bin/env bash

install_obsidian() {
    local os version

    os=$(dotfiles_os) || return 1
    if command -v obsidian >/dev/null 2>&1 ||
        { [[ "$os" == macos ]] && brew list --cask obsidian >/dev/null 2>&1; }; then
        return 0
    fi

    case "$os" in
        macos)
            brew install --cask obsidian
            ;;
        ubuntu|debian)
            [[ "$(uname -m)" == x86_64 ]] || {
                echo "Obsidian only publishes a Debian package for amd64; use its arm64 AppImage on this machine." >&2
                return 1
            }
            version=$(github_latest_tag obsidianmd/obsidian-releases)
            version=${version#v}
            linux_install_deb_url \
                "https://github.com/obsidianmd/obsidian-releases/releases/download/v$version/obsidian_${version}_amd64.deb" \
                obsidian
            ;;
        arch)
            linux_packages_install obsidian
            ;;
        *) return 1 ;;
    esac
}
