#!/usr/bin/env bash

# Kickstart tracks upstream master and can adopt APIs before distro packages do.
# Install the official Neovim nightly for every platform so config and editor
# versions move together. The user-local launcher wins over apt, pacman, and
# Homebrew because ~/.local/bin is PATH-first in dot/zshrc.

_neovim_release_layout() {
    local os=$1 machine=$2 platform architecture
    case "$os" in
        macos) platform=macos ;;
        ubuntu|debian|arch) platform=linux ;;
        *) return 1 ;;
    esac
    case "$machine" in
        x86_64|amd64) architecture=x86_64 ;;
        arm64|aarch64) architecture=arm64 ;;
        *) return 1 ;;
    esac
    printf 'nvim-%s-%s.tar.gz\tnvim-%s-%s\n' \
        "$platform" "$architecture" "$platform" "$architecture"
}

_neovim_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        shasum -a 256 "$1" | awk '{ print $1 }'
    fi
}

_neovim_release_asset() {
    local asset=$1 metadata record url digest
    metadata=$(download_stdout https://api.github.com/repos/neovim/neovim/releases/tags/nightly) || return 1
    record=$(printf '%s' "$metadata" | jq -er --arg asset "$asset" '
        [.assets[] | select(.name == $asset)] as $matches |
        if ($matches | length) == 1 then
          $matches[0] | [.browser_download_url, .digest] | @tsv
        else
          error("nightly asset missing or duplicated")
        end
    ') || return 1
    IFS=$'\t' read -r url digest <<<"$record"
    digest=${digest#sha256:}
    [[ "$url" == https://github.com/neovim/neovim/releases/download/nightly/* &&
       "$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    printf '%s\t%s\n' "$url" "$(printf '%s' "$digest" | tr '[:upper:]' '[:lower:]')"
}

_neovim_is_compatible() {
    local probe
    probe=$("$1" --clean --headless \
        '+lua io.stdout:write("NVIM_PACK_COMPAT=" .. type(vim.pack) .. ":" .. vim.fn.exists("##PackChanged"))' \
        +qa 2>/dev/null) || return 1
    [[ "$probe" == NVIM_PACK_COMPAT=table:1 ]]
}

install_neovim() {
    local os layout asset dirname release url expected actual work_dir archive extracted
    local data_home target target_parent stage backup bin_dir launcher temporary_link installed_version

    os=$(dotfiles_os) || return 1
    layout=$(_neovim_release_layout "$os" "$(uname -m)") || {
        echo "Neovim nightly is unavailable for $os/$(uname -m)." >&2
        return 1
    }
    IFS=$'\t' read -r asset dirname <<<"$layout"
    release=$(_neovim_release_asset "$asset") || {
        echo "Could not resolve the official Neovim nightly asset." >&2
        return 1
    }
    IFS=$'\t' read -r url expected <<<"$release"

    data_home=${XDG_DATA_HOME:-$HOME/.local/share}
    target="$data_home/nvim-nightly"
    target_parent=${target%/*}
    bin_dir="$HOME/.local/bin"
    launcher="$bin_dir/nvim"
    if [[ -e "$launcher" && ! -L "$launcher" ]]; then
        echo "Refusing to replace non-symlink Neovim launcher: $launcher" >&2
        return 1
    fi

    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-neovim.XXXXXX") || return 1
    archive="$work_dir/$asset"
    if ! download_file "$url" "$archive"; then
        rm -rf "$work_dir"
        return 1
    fi
    actual=$(_neovim_sha256 "$archive") || {
        rm -rf "$work_dir"
        return 1
    }
    actual=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')
    if [[ "$actual" != "$expected" ]]; then
        printf 'Checksum mismatch for %s\nExpected: %s\nActual:   %s\n' \
            "$asset" "$expected" "$actual" >&2
        rm -rf "$work_dir"
        return 1
    fi
    if ! tar -xzf "$archive" -C "$work_dir"; then
        rm -rf "$work_dir"
        return 1
    fi
    extracted="$work_dir/$dirname"
    if [[ ! -x "$extracted/bin/nvim" ]] || ! _neovim_is_compatible "$extracted/bin/nvim"; then
        echo "Downloaded Neovim nightly does not provide the required vim.pack APIs." >&2
        rm -rf "$work_dir"
        return 1
    fi

    mkdir -p "$target_parent" "$bin_dir" || {
        rm -rf "$work_dir"
        return 1
    }
    stage=$(mktemp -d "$target_parent/.nvim-nightly.XXXXXX") || {
        rm -rf "$work_dir"
        return 1
    }
    if ! cp -a "$extracted/." "$stage/"; then
        rm -rf "$work_dir" "$stage"
        return 1
    fi
    rm -rf "$work_dir"

    backup="$target_parent/.nvim-nightly.previous.$$"
    rm -rf "$backup"
    if [[ -e "$target" ]] && ! mv "$target" "$backup"; then
        rm -rf "$stage"
        return 1
    fi
    if ! mv "$stage" "$target"; then
        [[ ! -e "$backup" ]] || mv "$backup" "$target" || true
        return 1
    fi

    temporary_link="$bin_dir/.nvim.$$"
    rm -f "$temporary_link"
    if ! ln -s "$target/bin/nvim" "$temporary_link" || ! mv -f "$temporary_link" "$launcher"; then
        rm -f "$temporary_link"
        rm -rf "$target"
        [[ ! -e "$backup" ]] || mv "$backup" "$target" || true
        return 1
    fi
    rm -rf "$backup"

    # Make the managed launcher visible immediately to the catalog process;
    # new interactive shells already prepend this directory in dot/zshrc.
    PATH="$bin_dir:$PATH"
    export PATH
    hash -r 2>/dev/null || true
    if [[ $(command -v nvim 2>/dev/null) != "$launcher" ]]; then
        echo "Managed Neovim was installed but is not first on PATH: $launcher" >&2
        return 1
    fi
    installed_version=$("$launcher" --version | head -n 1)
    printf '%s is selected at %s\n' "$installed_version" "$launcher"
}
