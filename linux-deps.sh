#!/usr/bin/env bash
# shellcheck disable=SC2154
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=installers/source_installers.sh
source installers/source_installers.sh

run_optional() {
    local name="$1"
    shift
    if ! "$@"; then
        echo "Warning: $name failed; continuing." >&2
        return 1
    fi
}

ensure_command_alias() {
    local command_name="$1"
    local packaged_name="$2"
    local packaged_path target="$HOME/.local/bin/$command_name"

    command -v "$command_name" >/dev/null 2>&1 && return 0
    packaged_path=$(command -v "$packaged_name" 2>/dev/null) || return 0
    [[ ! -e "$target" && ! -L "$target" ]] || return 0
    mkdir -p "${target%/*}"
    ln -s "$packaged_path" "$target"
}

if ! linux_packages_optimize_mirrors; then
    echo "Warning: mirror optimization failed; using the current mirrors." >&2
fi

case "$os_id" in
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

        linux_packages_refresh
        linux_packages_install "${required[@]}"
        if ((${#optional[@]})); then
            run_optional "optional distro packages" \
                linux_packages_install_available "${optional[@]}" || true
            run_optional "language distro packages" \
                linux_packages_install_available "${language[@]}" || true
        fi
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
        ((${#optional[@]} == 0)) ||
            run_optional "optional distro packages" \
                linux_packages_install_available "${optional[@]}" || true
        ;;
    *)
        echo "Unsupported Linux distribution: $os_id" >&2
        exit 1
        ;;
esac

# Debian renames these executables to avoid package-name collisions.
ensure_command_alias fd fdfind
ensure_command_alias bat batcat

if [[ "$os_id" == ubuntu || "$os_id" == debian ]]; then
    for app in bitwarden chrome code discord docker ghostty lazygit neovim obsidian; do
        run_optional "$app" "install_$app" || true
    done
else
    # Arch provides these applications directly; the installer only performs
    # Docker's service and group setup once the package is present.
    run_optional docker install_docker || true
fi

# No distro package currently exists for Herdr or Claude Code. Bun and
# Lazydocker installers are no-ops when their native Arch packages are already
# present.
for app in bun claude_code herdr lazydocker; do
    run_optional "$app" "install_$app" || true
done

command -v npm >/dev/null 2>&1 &&
    run_optional "Node packages" install_node_deps || true
if command -v cargo >/dev/null 2>&1; then
    run_optional "Rust packages" install_rust_deps || true
    if [[ "$os_id" != arch ]]; then
        run_optional yazi install_yazi || true
    fi
fi

# Package-manager dependencies are required; individual applications are best effort.
exit 0
