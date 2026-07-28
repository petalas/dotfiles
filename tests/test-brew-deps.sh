#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-brew-deps.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/installers" "$fixture/home" "$fixture/lib"
cp "$repo_dir/brew-deps.sh" "$fixture/brew-deps.sh"
cp "$repo_dir/lib/homebrew.sh" "$fixture/lib/homebrew.sh"
: >"$fixture/Brewfile"
: >"$fixture/setup-brew.sh"

cat >"$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >>"$TEST_STEPS"
case "$1" in
    update) exit 0 ;;
    bundle) [[ "${TEST_SCENARIO:-}" != bundle_failure ]] ;;
    *) exit 1 ;;
esac
EOF
for command in npm cargo; do
    cat >"$fixture/bin/$command" <<EOF
#!/usr/bin/env bash
exit 0
EOF
done
cat >"$fixture/installers/source_installers.sh" <<'EOF'
record() { printf '%s\n' "$1" >>"$TEST_STEPS"; }
install_ghostty() { record ghostty; }
install_node_deps() { record node-deps; }
install_bun() { record bun; }
install_rust_deps() { record rust-deps; }
install_yazi() { record yazi; }
EOF
chmod +x "$fixture/bin"/* "$fixture/brew-deps.sh"

steps="$fixture/steps"
run_test() {
    local scenario="$1"
    : >"$steps"
    env TEST_SCENARIO="$scenario" TEST_STEPS="$steps" HOME="$fixture/home" \
        PATH="$fixture/bin:/usr/bin:/bin" bash "$fixture/brew-deps.sh" \
        >"$fixture/$scenario.log" 2>&1
}

run_test success
for expected in \
    'brew update' \
    "brew bundle --no-upgrade --file=$fixture/Brewfile" \
    ghostty node-deps bun rust-deps yazi; do
    grep -Fxq "$expected" "$steps"
done

# A broken cask should not prevent unrelated language tools from running.
run_test bundle_failure
for expected in ghostty node-deps bun rust-deps yazi; do
    grep -Fxq "$expected" "$steps"
done
grep -Fq 'Brewfile installation failed' "$fixture/bundle_failure.log"

echo "Homebrew dependency continuation tests passed."
