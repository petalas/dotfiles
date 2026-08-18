#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-language-deps.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"
log="$fixture/commands"
export LANGUAGE_DEPS_LOG="$log"
export HOME="$fixture/home"
export PATH="$fixture/bin:/usr/bin:/bin"
export DOTFILES_BATCH_RETRIES=1 DOTFILES_BATCH_RETRY_DELAY_SECONDS=0

cat >"$fixture/bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
if IFS= read -r input; then
    printf 'stdin: %s\n' "$input" >>"$LANGUAGE_DEPS_LOG"
fi
[[ "${FAIL_NPM:-0}" != 1 ]]
EOF
cat >"$fixture/bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo %s\n' "$*" >>"$LANGUAGE_DEPS_LOG"
[[ "$*" != *ripgrep* || "${FAIL_CARGO:-0}" != 1 ]]
EOF
chmod +x "$fixture/bin"/*

# shellcheck source=../lib/packages.sh
source "$repo_dir/lib/packages.sh"
# shellcheck source=../installers/install_node_deps.sh
source "$repo_dir/installers/install_node_deps.sh"
# shellcheck source=../installers/install_rust_deps.sh
source "$repo_dir/installers/install_rust_deps.sh"

: >"$log"
install_node_deps <<<"interactive input"
for package in @openai/codex typescript typescript-language-server; do
    grep -Fq "$package" "$log"
done
grep -Fq '@earendil-works/pi-coding-agent' "$log"
! grep -Fq 'stdin:' "$log"

if FAIL_NPM=1 install_node_deps; then
    echo "Expected npm failure to propagate" >&2
    exit 1
fi
# The separately configured Pi package must still run after another npm package fails.
grep -Fq '@earendil-works/pi-coding-agent' "$log"

: >"$log"
install_rust_deps
for package in tree-sitter-cli ripgrep wasm-bindgen-cli cargo-edit tealdeer bat bottom du-dust watchexec-cli; do
    grep -Fq "$package" "$log"
done

: >"$log"
if FAIL_CARGO=1 install_rust_deps; then
    echo "Expected Cargo failure to propagate" >&2
    exit 1
fi
# The failed crate is isolated, while unrelated crates continue in batches.
grep -Fq 'cargo install --locked ripgrep' "$log"
grep -Fq 'watchexec-cli' "$log"

echo "Language dependency tests passed."
