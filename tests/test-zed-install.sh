#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-zed-install.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/.local/bin"

make_archive() {
    local version=$1 archive=$2 build_dir="$fixture/build-$1"
    rm -rf "$build_dir"
    mkdir -p "$build_dir/zed.app/bin" "$build_dir/zed.app/share/applications" \
        "$build_dir/zed.app/share/icons/hicolor/512x512/apps"
    cat >"$build_dir/zed.app/bin/zed" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == --version ]]; then
    printf 'Zed $version\\n'
fi
EOF
    chmod +x "$build_dir/zed.app/bin/zed"
    cat >"$build_dir/zed.app/share/applications/dev.zed.Zed.desktop" <<'EOF'
[Desktop Entry]
Name=Zed
Exec=zed
Icon=zed
EOF
    printf 'icon\n' >"$build_dir/zed.app/share/icons/hicolor/512x512/apps/zed.png"
    tar -C "$build_dir" -czf "$archive" zed.app
}

archive="$fixture/zed.tar.gz"
make_archive 1.16.1 "$archive"

(
    export HOME="$fixture/home"
    export PATH="$HOME/.local/bin:/usr/bin:/bin"
    export DOTFILES_OS_OVERRIDE=debian
    export ZED_TEST_ARCHIVE="$archive"
    # shellcheck source=../installers/source_installers.sh disable=SC1091
    source "$repo_dir/installers/source_installers.sh"

    download_stdout() {
        local digest
        digest=$(sha256sum "$ZED_TEST_ARCHIVE" | awk '{ print $1 }')
        printf '{"tag_name":"v1.16.1","assets":[{"name":"zed-linux-x86_64.tar.gz","browser_download_url":"https://github.com/zed-industries/zed/releases/download/v1.16.1/zed-linux-x86_64.tar.gz","digest":"sha256:%s"}]}' "$digest"
    }
    download_file() { cp "$ZED_TEST_ARCHIVE" "$2"; }

    install_zed
    [[ -x "$HOME/.local/zed.app/bin/zed" ]]
    [[ -L "$HOME/.local/bin/zed" ]]
    [[ $(readlink "$HOME/.local/bin/zed") == "$HOME/.local/zed.app/bin/zed" ]]
    [[ $(command -v zed) == "$HOME/.local/bin/zed" ]]
    [[ $(zed --version) == 'Zed 1.16.1' ]]
    grep -Fxq "Exec=$HOME/.local/zed.app/bin/zed" "$HOME/.local/share/applications/dev.zed.Zed.desktop"
    grep -Fxq "Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png" \
        "$HOME/.local/share/applications/dev.zed.Zed.desktop"

    [[ $(_zed_release_asset x86_64) == zed-linux-x86_64.tar.gz ]]
    [[ $(_zed_release_asset aarch64) == zed-linux-aarch64.tar.gz ]]
    if _zed_release_asset mips64 >/dev/null; then
        echo 'Expected an unsupported Zed architecture to be rejected.' >&2
        exit 1
    fi

    make_archive 1.16.2 "$ZED_TEST_ARCHIVE"
    rm "$HOME/.local/bin/zed"
    mkdir "$HOME/.local/bin/zed"
    if install_zed >/dev/null 2>&1; then
        echo 'Zed installer accepted an occupied command path.' >&2
        exit 1
    fi
    [[ $("$HOME/.local/zed.app/bin/zed" --version) == 'Zed 1.16.1' ]]
    rm -rf "$HOME/.local/bin/zed"
    install_zed
    [[ $(zed --version) == 'Zed 1.16.2' ]]

    download_stdout() {
        printf '{"tag_name":"v1.16.3","assets":[{"name":"zed-linux-x86_64.tar.gz","browser_download_url":"https://example.invalid/zed.tar.gz","digest":"sha256:%064d"}]}' 0
    }
    if install_zed >/dev/null 2>&1; then
        echo 'Zed installer accepted an invalid release digest.' >&2
        exit 1
    fi
    [[ $(zed --version) == 'Zed 1.16.2' ]]
)

printf 'Zed installation tests passed.\n'
