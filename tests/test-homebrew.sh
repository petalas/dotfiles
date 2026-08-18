#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-homebrew.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
log="$fixture/brew.log"
cat >"$fixture/Brewfile" <<'EOF'
brew "working"
brew "vendor/tap/tool", trusted: true
EOF
cat >"$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOMEBREW_TEST_LOG"
case "$*" in
    'bundle --no-upgrade --file='*) [[ "$*" != *"$HOMEBREW_MAIN_FILE"* ]] ;;
    'bundle list --tap '*) : ;;
    'bundle list --formula '*) printf '%s\n' working vendor/tap/tool ;;
    'bundle list --cask '*) : ;;
    'bundle check --file='*) exit 1 ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$fixture/bin/brew"
PATH="$fixture/bin:/usr/bin:/bin"
export PATH HOMEBREW_TEST_LOG="$log" HOMEBREW_MAIN_FILE="$fixture/Brewfile"
# shellcheck source=../lib/homebrew.sh
source "$repo_dir/lib/homebrew.sh"

entry="$fixture/trusted.entry"
_homebrew_extract_entry "$fixture/Brewfile" formula vendor/tap/tool "$entry"
grep -Fxq 'brew "vendor/tap/tool", trusted: true' "$entry"
homebrew_bundle_install_resilient "$fixture/Brewfile"
grep -Fq 'bundle list --formula' "$log"

printf 'Homebrew resilient reconciliation tests passed.\n'
