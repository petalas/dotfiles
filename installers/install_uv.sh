#!/usr/bin/env bash

install_uv() {
    local os bin_dir="$HOME/.local/bin"
    os=$(dotfiles_os) || return 1
    case "$os" in
        debian|ubuntu) ;;
        *)
            printf 'The direct uv installer is unsupported on %s\n' "$os" >&2
            return 1
            ;;
    esac

    if [[ ! -x "$bin_dir/uv" || ! -x "$bin_dir/uvx" ]]; then
        echo "Installing uv..."
        UV_INSTALL_DIR="$bin_dir" UV_NO_MODIFY_PATH=1 \
            run_downloaded_script sh https://astral.sh/uv/install.sh || return 1
    fi

    export PATH="$bin_dir:$PATH"
    hash -r 2>/dev/null || true
    [[ "$(command -v uv 2>/dev/null || true)" == "$bin_dir/uv" && -x "$bin_dir/uvx" ]] || {
        echo "The managed uv executables are not active" >&2
        return 1
    }
}
