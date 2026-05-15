#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh

# Install / upgrade Neovim to the latest nightly. Safe to run repeatedly —
# pulls a fresh tarball each invocation. We track nightly (not stable)
# because kickstart's treesitter config now uses APIs (vim.list.unique,
# require('nvim-treesitter').install(...)) only available on nvim 0.12+.
#
# Linux/macOS: official tarball from neovim/neovim releases → /opt/nvim
# Arch:        AUR neovim-nightly-bin via paru
install_neovim() {
    local tag="nightly"
    local tarball url arch_tag dirname

    case "$os_id" in
        ubuntu|debian)
            tarball="nvim-linux-x86_64.tar.gz"
            dirname="nvim-linux-x86_64"
            url="https://github.com/neovim/neovim/releases/download/${tag}/${tarball}"
            echo "Installing ${yellow}nvim (${tag})${reset} ..."
            curl -fsSL "$url" -o "/tmp/${tarball}" || { echo "${red}nvim: download failed${reset}"; return 1; }
            sudo rm -rf /opt/nvim
            sudo tar -C /opt -xzf "/tmp/${tarball}"
            sudo mv "/opt/${dirname}" /opt/nvim
            rm -f "/tmp/${tarball}"
            ;;
        macos)
            case "$(uname -m)" in
                arm64|aarch64) arch_tag="arm64" ;;
                x86_64)        arch_tag="x86_64" ;;
                *) echo "${red}nvim: unsupported mac arch: $(uname -m)${reset}"; return 1 ;;
            esac
            tarball="nvim-macos-${arch_tag}.tar.gz"
            dirname="nvim-macos-${arch_tag}"
            url="https://github.com/neovim/neovim/releases/download/${tag}/${tarball}"
            echo "Installing ${yellow}nvim (${tag}, ${arch_tag})${reset} ..."
            curl -fsSL "$url" -o "/tmp/${tarball}" || { echo "${red}nvim: download failed${reset}"; return 1; }
            sudo rm -rf /opt/nvim
            sudo tar -C /opt -xzf "/tmp/${tarball}"
            sudo mv "/opt/${dirname}" /opt/nvim
            rm -f "/tmp/${tarball}"
            ;;
        arch)
            echo "Installing ${yellow}nvim (${tag})${reset} via AUR ..."
            paru -S --noconfirm --needed neovim-nightly-bin
            ;;
        *)
            echo "${red}nvim: unsupported OS: ${os_id}${reset}"
            return 1
            ;;
    esac
}

# Standalone invocation: bootstrap os_id if not already set by the harness.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -z "${os_id:-}" ]]; then
        if [[ "$OSTYPE" == darwin* ]]; then
            os_id="macos"
        elif [[ -f /etc/os-release ]]; then
            os_id=$(grep -w ID /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
            [[ "$os_id" == "archarm" ]] && os_id="arch"
        fi
    fi
    install_neovim
fi
