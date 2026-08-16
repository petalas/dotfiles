#!/usr/bin/env bash
# shellcheck disable=SC2154

install_obsidian() {
    local version

    if command -v obsidian >/dev/null 2>&1 ||
        { [[ "$os_id" == macos ]] && brew list --cask obsidian >/dev/null 2>&1; }; then
        return 0
    fi

    case "$os_id" in
        macos)
            brew install --cask obsidian
            ;;
        ubuntu|debian)
            [[ "$(uname -m)" == x86_64 ]] || {
                echo "Obsidian only publishes a Debian package for amd64; use its arm64 AppImage on this machine." >&2
                return 1
            }
            version=$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
                jq -r '.tag_name | ltrimstr("v")')
            [[ -n "$version" && "$version" != null ]] || return 1
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Run this installer through: ./install obsidian" >&2
    exit 2
fi
