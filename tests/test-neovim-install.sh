#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-neovim-install.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/.local/bin" "$fixture/old-bin"

cat >"$fixture/old-bin/nvim" <<'EOF'
#!/usr/bin/env bash
printf 'NVIM v0.10.4\n'
EOF
chmod +x "$fixture/old-bin/nvim"

make_archive() {
    local version=$1 archive=$2 build_dir="$fixture/build-$1"
    rm -rf "$build_dir"
    mkdir -p "$build_dir/nvim-linux-x86_64/bin"
    cat >"$build_dir/nvim-linux-x86_64/bin/nvim" <<EOF
#!/usr/bin/env bash
if [[ \$* == *NVIM_PACK_COMPAT* ]]; then
    printf 'NVIM_PACK_COMPAT=table:1'
elif [[ \${1:-} == --version ]]; then
    printf 'NVIM v$version\\n'
fi
exit 0
EOF
    chmod +x "$build_dir/nvim-linux-x86_64/bin/nvim"
    tar -C "$build_dir" -czf "$archive" nvim-linux-x86_64
}

archive="$fixture/nvim.tar.gz"
make_archive 0.13.0-dev "$archive"

(
    export HOME="$fixture/home"
    export PATH="$HOME/.local/bin:$fixture/old-bin:/usr/bin:/bin"
    export DOTFILES_OS_OVERRIDE=debian
    export NVIM_TEST_ARCHIVE="$archive"
    # shellcheck source=../installers/source_installers.sh
    source "$repo_dir/installers/source_installers.sh"
    uname() {
        [[ "${1:-}" == -m ]] && { printf 'x86_64\n'; return; }
        command uname "$@"
    }

    download_stdout() {
        local digest
        digest=$(_neovim_sha256 "$NVIM_TEST_ARCHIVE")
        printf '{"assets":[{"name":"nvim-linux-x86_64.tar.gz","browser_download_url":"https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz","digest":"sha256:%s"}]}' "$digest"
    }
    download_file() { cp "$NVIM_TEST_ARCHIVE" "$2"; }

    # An old distro binary must not short-circuit installation of the managed nightly.
    [[ $(command -v nvim) == "$fixture/old-bin/nvim" ]]
    install_neovim
    [[ -x "$HOME/.local/share/nvim-nightly/bin/nvim" ]]
    [[ -L "$HOME/.local/bin/nvim" ]]
    [[ $(readlink "$HOME/.local/bin/nvim") == "$HOME/.local/share/nvim-nightly/bin/nvim" ]]
    hash -r
    [[ $(command -v nvim) == "$HOME/.local/bin/nvim" ]]
    [[ $(nvim --version | head -n 1) == 'NVIM v0.13.0-dev' ]]

    # Reconciliation upgrades an existing managed install rather than treating presence as current.
    make_archive 0.13.1-dev "$NVIM_TEST_ARCHIVE"
    install_neovim
    [[ $(nvim --version | head -n 1) == 'NVIM v0.13.1-dev' ]]

    # A failed integrity check must leave the last working installation selected.
    download_stdout() {
        printf '{"assets":[{"name":"nvim-linux-x86_64.tar.gz","browser_download_url":"https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz","digest":"sha256:%064d"}]}' 0
    }
    make_archive 0.13.2-dev "$NVIM_TEST_ARCHIVE"
    if install_neovim; then
        echo 'Neovim installer accepted an invalid release digest.' >&2
        exit 1
    fi
    hash -r
    [[ $(nvim --version | head -n 1) == 'NVIM v0.13.1-dev' ]]
)

printf 'Neovim nightly installation tests passed.\n'
