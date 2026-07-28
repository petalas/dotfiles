#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-language-deps.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
log="$fixture/commands"
export LANGUAGE_DEPS_LOG="$log"
export PATH="$fixture/bin:/usr/bin:/bin"

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

# shellcheck source=../installers/install_node_deps.sh
source "$repo_dir/installers/install_node_deps.sh"
# shellcheck source=../installers/install_rust_deps.sh
source "$repo_dir/installers/install_rust_deps.sh"

: >"$log"
install_node_deps <<<"interactive input"
grep -Fq '@anthropic-ai/claude-code @openai/codex typescript typescript-language-server' "$log"
grep -Fq '@earendil-works/pi-coding-agent' "$log"
! grep -Fq 'stdin:' "$log"

if FAIL_NPM=1 install_node_deps; then
    echo "Expected npm failure to propagate" >&2
    exit 1
fi

: >"$log"
if FAIL_CARGO=1 install_rust_deps; then
    echo "Expected Cargo failure to propagate" >&2
    exit 1
fi
# The simple fail-fast loop should stop at the failed package.
grep -Fq 'cargo install --locked ripgrep' "$log"
! grep -Fq 'watchexec-cli' "$log"

echo "Language dependency tests passed."
