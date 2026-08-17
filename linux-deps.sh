#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$root_dir"
# shellcheck source=installers/source_installers.sh
source installers/source_installers.sh

os=$(dotfiles_os) || {
    echo "Unsupported Linux distribution." >&2
    exit 1
}
failures=()
run_best_effort() {
    local label="$1"
    shift
    if ! "$@"; then
        echo "Warning: $label failed; continuing." >&2
        failures+=("$label")
    fi
    return 0
}

ensure_command_alias() {
    local command_name="$1"
    local packaged_name="$2"
    local packaged_path target="$HOME/.local/bin/$command_name"

    command -v "$command_name" >/dev/null 2>&1 && return 0
    packaged_path=$(command -v "$packaged_name" 2>/dev/null) || return 0
    mkdir -p "${target%/*}"
    if [[ -L "$target" ]]; then
        [[ "$(readlink "$target")" == "$packaged_path" ]] && return 0
        rm -f "$target"
    elif [[ -e "$target" ]]; then
        echo "Cannot manage command alias over existing file: $target" >&2
        return 1
    fi
    ln -s "$packaged_path" "$target"
}

run_best_effort "mirror optimization" linux_packages_optimize_mirrors
linux_packages_refresh

case "$os" in
    ubuntu|debian)
        required=(
            ca-certificates build-essential clang cmake curl git gnupg jq locales
            make mosh pkg-config rsync tar tmux unzip wget zip zsh
        )
        optional=(
            aria2 bat bc btop eza fd-find ffmpeg fzf gh htop imagemagick iperf3
            lazygit mediainfo neovim nmap pass procs python3 python3-venv ripgrep
            shellcheck sshpass tealdeer tree-sitter-cli xclip xdg-utils xh
        )
        language=(cargo default-jdk gradle kotlin nodejs npm rustc)

        linux_packages_install "${required[@]}"
        run_best_effort "optional distro packages" \
            linux_packages_install_available "${optional[@]}"
        run_best_effort "language distro packages" \
            linux_packages_install_available "${language[@]}"
        ;;
    arch)
        required=(
            base-devel ca-certificates clang cmake curl git gnupg jq mosh openssl
            pkgconf rsync tar tmux unzip wget zip zsh
        )
        optional=(
            aria2 bat bc bind bitwarden bottom btop bun cargo-edit chromium code
            discord docker docker-buildx docker-compose dust eza fd ffmpeg fzf
            ghostty github-cli gradle htop imagemagick iperf3 jdk-openjdk kotlin
            lazydocker lazygit libnotify libxml2 mediainfo neovim nmap nodejs npm
            obsidian openssh p7zip pass perf poppler procs python python-virtualenv ripgrep
            rust shellcheck sshpass tealdeer tree-sitter-cli watchexec wasm-bindgen
            xclip xdg-utils xh yazi
        )

        linux_packages_install "${required[@]}"
        run_best_effort "optional distro packages" \
            linux_packages_install_available "${optional[@]}"
        ;;
    *)
        echo "Unsupported Linux distribution: $os" >&2
        exit 1
        ;;
esac

run_best_effort "fd command alias" ensure_command_alias fd fdfind
run_best_effort "bat command alias" ensure_command_alias bat batcat

if [[ "$os" == ubuntu || "$os" == debian ]]; then
    for app in bitwarden chrome code discord docker ghostty lazygit neovim obsidian; do
        run_best_effort "$app" "install_$app"
    done
else
    run_best_effort docker install_docker
fi

for app in bun claude_code herdr lazydocker; do
    run_best_effort "$app" "install_$app"
done

if command -v npm >/dev/null 2>&1; then
    run_best_effort "Node packages" install_node_deps
fi
if command -v cargo >/dev/null 2>&1; then
    run_best_effort "Rust packages" install_rust_deps
    [[ "$os" == arch ]] || run_best_effort yazi install_yazi
fi

if ((${#failures[@]})); then
    printf 'Best-effort Linux setup failures: %s\n' "${failures[*]}" >&2
fi
# System package-manager dependencies are required; individual applications
# and language add-ons remain best effort.
exit 0
