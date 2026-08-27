#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-managed-toolchains.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"
log="$fixture/commands"

for tool in node npm cargo rustc java gradle kotlin mvn; do
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

run_installer_operation() {
    local sub_id=$1 label=$2 operation_result=0
    shift 2

    printf 'operation start %s %s\n' "$sub_id" "$label" >>"$MANAGED_TOOLCHAIN_TEST_LOG"
    "$@" || operation_result=$?
    printf 'operation settled %s %s %s\n' "$sub_id" "$label" "$operation_result" \
        >>"$MANAGED_TOOLCHAIN_TEST_LOG"
    return "$operation_result"
}

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
        'https://get.sdkman.io?ci=true&rcupdate=false')
            mkdir -p "$SDKMAN_DIR/bin" "$SDKMAN_DIR/etc"
            printf 'sdkman_auto_answer=false\n' >"$SDKMAN_DIR/etc/config"
            cat >"$SDKMAN_DIR/bin/sdkman-init.sh" <<'EOF'
case $- in *u*) return 91 ;; esac
sdk() {
    case $- in *u*) return 92 ;; esac
    printf 'sdk %s\n' "$*" >>"$MANAGED_TOOLCHAIN_TEST_LOG"
    [[ "$1" == install ]] || return 0
    local candidate=$2 executable=$2
    [[ "$candidate" != maven ]] || executable=mvn
    mkdir -p "$SDKMAN_DIR/candidates/$candidate/current/bin"
    printf '#!/usr/bin/env bash\nprintf "%s managed\\n"\n' "$candidate" \
        >"$SDKMAN_DIR/candidates/$candidate/current/bin/$executable"
    chmod +x "$SDKMAN_DIR/candidates/$candidate/current/bin/$executable"
    # Match SDKMAN's real behavior when the candidate path already exists
    # later in PATH: leave it there instead of moving it to the front.
    case ":$PATH:" in
        *":$SDKMAN_DIR/candidates/$candidate/current/bin:"*) ;;
        *) export PATH="$SDKMAN_DIR/candidates/$candidate/current/bin:$PATH" ;;
    esac
}
EOF
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
grep -Fq 'interpreter=sh url=https://sh.rustup.rs args=-y --no-modify-path --profile minimal --default-toolchain none' "$log"
grep -Fxq 'rustup set profile default' "$log"
grep -Fxq 'rustup update stable' "$log"
grep -Fxq 'rustup default stable' "$log"
[[ "$(install_node_operations)" == $'nvm\tEnsure nvm\nnode\tEnsure Node and npm' ]]
[[ "$(install_rust_operations)" == $'rustup\tEnsure rustup\nstable\tEnsure the stable Rust toolchain' ]]

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

PATH="$fixture/bin:/usr/bin:/bin"
unset SDKMAN_DIR
: >"$log"
# Inherited SDKMAN paths can sit behind system or Homebrew commands. Candidate
# installation must promote the managed executable instead of trusting the
# loader's path-presence check.
export SDKMAN_DIR="$HOME/.sdkman"
PATH="$fixture/bin:/usr/bin:/bin"
for candidate in java gradle kotlin maven; do
    PATH="$PATH:$SDKMAN_DIR/candidates/$candidate/current/bin"
done
for candidate in java gradle kotlin maven; do
    "install_$candidate"
done
[[ $(grep -Fc 'interpreter=bash url=https://get.sdkman.io?ci=true&rcupdate=false' "$log") == 1 ]]
[[ $(grep -Fc 'operation start sdkman Ensure SDKMAN' "$log") == 4 ]]
[[ $(grep -Fc 'operation settled sdkman Ensure SDKMAN 0' "$log") == 4 ]]
for candidate in java gradle kotlin maven; do
    case "$candidate" in
        java) label=Java ;;
        gradle) label=Gradle ;;
        kotlin) label=Kotlin ;;
        maven) label=Maven ;;
    esac
    [[ "$("install_${candidate}_operations")" == $'sdkman\tEnsure SDKMAN\n'"$candidate"$'\tEnsure '"$label" ]]
    grep -Fxq "operation start $candidate Ensure $label" "$log"
    grep -Fxq "operation settled $candidate Ensure $label 0" "$log"
    grep -Fxq "sdk install $candidate" "$log"
done
grep -Fxq 'sdkman_auto_answer=true' "$SDKMAN_DIR/etc/config"
[[ $(command -v java) == "$SDKMAN_DIR/candidates/java/current/bin/java" ]]
[[ $(command -v gradle) == "$SDKMAN_DIR/candidates/gradle/current/bin/gradle" ]]
[[ $(command -v kotlin) == "$SDKMAN_DIR/candidates/kotlin/current/bin/kotlin" ]]
[[ $(command -v mvn) == "$SDKMAN_DIR/candidates/maven/current/bin/mvn" ]]
[[ $- == *u* ]]

printf 'Managed toolchain installer tests passed.\n'
