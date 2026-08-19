#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-managed-toolchains.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"
log="$fixture/commands"

for tool in node npm cargo rustc; do
    cat >"$fixture/bin/$tool" <<EOF
#!/usr/bin/env bash
printf 'system $tool\n'
EOF
    chmod +x "$fixture/bin/$tool"
done

export HOME="$fixture/home"
export PATH="$fixture/bin:/usr/bin:/bin"
export DOTFILES_OS_OVERRIDE=debian
export MANAGED_TOOLCHAIN_TEST_LOG="$log"
unset NVM_DIR CARGO_HOME RUSTUP_HOME

# shellcheck source=../installers/source_installers.sh
# shellcheck disable=SC1091
source "$repo_dir/installers/source_installers.sh"

run_downloaded_script() {
    local interpreter=$1 url=$2
    shift 2
    printf 'download profile=%s interpreter=%s url=%s args=%s uv_install_dir=%s uv_no_modify_path=%s\n' \
        "${PROFILE:-}" "$interpreter" "$url" "$*" "${UV_INSTALL_DIR:-}" "${UV_NO_MODIFY_PATH:-}" \
        >>"$MANAGED_TOOLCHAIN_TEST_LOG"
    case "$url" in
        https://raw.githubusercontent.com/nvm-sh/nvm/*/install.sh)
            mkdir -p "$NVM_DIR"
            cat >"$NVM_DIR/nvm.sh" <<'EOF'
nvm() {
    printf 'nvm %s\n' "$*" >>"$MANAGED_TOOLCHAIN_TEST_LOG"
    case "$1" in
        install)
            mkdir -p "$NVM_DIR/versions/node/v24.18.0/bin"
            printf '#!/usr/bin/env bash\nprintf "v24.18.0\\n"\n' \
                >"$NVM_DIR/versions/node/v24.18.0/bin/node"
            printf '#!/usr/bin/env bash\nprintf "11.6.0\\n"\n' \
                >"$NVM_DIR/versions/node/v24.18.0/bin/npm"
            chmod +x "$NVM_DIR/versions/node/v24.18.0/bin/node" \
                "$NVM_DIR/versions/node/v24.18.0/bin/npm"
            ;;
        use) export PATH="$NVM_DIR/versions/node/v24.18.0/bin:$PATH" ;;
    esac
}
EOF
            ;;
        https://sh.rustup.rs)
            mkdir -p "$CARGO_HOME/bin"
            cat >"$CARGO_HOME/bin/rustup" <<'EOF'
#!/usr/bin/env bash
printf 'rustup %s\n' "$*" >>"$MANAGED_TOOLCHAIN_TEST_LOG"
EOF
            cat >"$CARGO_HOME/bin/rustc" <<'EOF'
#!/usr/bin/env bash
printf 'rustc 1.95.0 (managed)\n'
EOF
            cat >"$CARGO_HOME/bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo 1.95.0 (managed)\n'
EOF
            chmod +x "$CARGO_HOME/bin/rustup" "$CARGO_HOME/bin/rustc" "$CARGO_HOME/bin/cargo"
            ;;
        https://bun.sh/install)
            mkdir -p "$HOME/.bun/bin"
            printf '#!/usr/bin/env bash\nprintf "1.2.0\\n"\n' >"$HOME/.bun/bin/bun"
            chmod +x "$HOME/.bun/bin/bun"
            ;;
        https://astral.sh/uv/install.sh)
            mkdir -p "$UV_INSTALL_DIR"
            for tool in uv uvx; do
                printf '#!/usr/bin/env bash\nprintf "uv 0.12.5\\n"\n' >"$UV_INSTALL_DIR/$tool"
                chmod +x "$UV_INSTALL_DIR/$tool"
            done
            ;;
        *) return 1 ;;
    esac
}

: >"$log"
install_node
[[ $(command -v node) == "$HOME/.nvm/versions/node/v24.18.0/bin/node" ]]
grep -Fq 'profile=/dev/null interpreter=bash url=https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh' "$log"
grep -Fxq 'nvm install node --latest-npm' "$log"
grep -Fxq 'nvm alias default node' "$log"
grep -Fxq 'nvm use node' "$log"

PATH="$fixture/bin:/usr/bin:/bin"
: >"$log"
install_rust
[[ $(command -v rustc) == "$HOME/.cargo/bin/rustc" ]]
grep -Fq 'interpreter=sh url=https://sh.rustup.rs args=-y --no-modify-path --profile default --default-toolchain stable' "$log"
grep -Fxq 'rustup set profile default' "$log"
grep -Fxq 'rustup update stable' "$log"
grep -Fxq 'rustup default stable' "$log"

PATH="$fixture/bin:/usr/bin:/bin"
: >"$log"
install_bun
[[ $(command -v bun) == "$HOME/.bun/bin/bun" ]]

PATH="$fixture/bin:/usr/bin:/bin"
: >"$log"
install_uv
[[ $(command -v uv) == "$HOME/.local/bin/uv" ]]
[[ -x "$HOME/.local/bin/uvx" ]]
grep -Fq 'interpreter=sh url=https://astral.sh/uv/install.sh args= uv_install_dir='"$HOME/.local/bin"' uv_no_modify_path=1' "$log"

printf 'Managed toolchain installer tests passed.\n'
