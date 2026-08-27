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
cask "claude-code@latest"
EOF
printf 'claude-code\n' >"$fixture/installed-casks"
cat >"$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOMEBREW_TEST_LOG"
case "$*" in
    'list --cask claude-code') grep -Fxq claude-code "$HOMEBREW_INSTALLED_CASKS" ;;
    'list --cask claude-code@latest') grep -Fxq claude-code@latest "$HOMEBREW_INSTALLED_CASKS" ;;
    'uninstall --cask --force claude-code') grep -Fxv claude-code "$HOMEBREW_INSTALLED_CASKS" >"$HOMEBREW_INSTALLED_CASKS.next" || true; mv "$HOMEBREW_INSTALLED_CASKS.next" "$HOMEBREW_INSTALLED_CASKS" ;;
    'install --cask --force claude-code@latest')
        [[ "${HOMEBREW_FAIL_LATEST:-0}" != 1 ]] || exit 29
        printf 'claude-code@latest\n' >>"$HOMEBREW_INSTALLED_CASKS"
        ;;
    'install --cask claude-code') printf 'claude-code\n' >>"$HOMEBREW_INSTALLED_CASKS" ;;
    'bundle --no-upgrade --file='*) [[ "$*" != *"$HOMEBREW_MAIN_FILE"* ]] ;;
    'bundle list --tap '*) : ;;
    'bundle list --formula '*) printf '%s\n' working vendor/tap/tool ;;
    'bundle list --cask '*) printf '%s\n' claude-code@latest ;;
    'bundle check --file='*) exit 1 ;;
    'outdated --formula --quiet') printf '%s\n' first second third ;;
    'outdated --cask --quiet') : ;;
    'upgrade --formula '*) cat >/dev/null ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$fixture/bin/brew"
PATH="$fixture/bin:/usr/bin:/bin"
export PATH HOMEBREW_TEST_LOG="$log" HOMEBREW_MAIN_FILE="$fixture/Brewfile" \
    HOMEBREW_INSTALLED_CASKS="$fixture/installed-casks"
# shellcheck source=../lib/homebrew.sh
source "$repo_dir/lib/homebrew.sh"

entry="$fixture/trusted.entry"
_homebrew_extract_entry "$fixture/Brewfile" formula vendor/tap/tool "$entry"
grep -Fxq 'brew "vendor/tap/tool", trusted: true' "$entry"
homebrew_bundle_install_resilient "$fixture/Brewfile"
grep -Fq 'bundle list --formula' "$log"
grep -Fxq 'uninstall --cask --force claude-code' "$log"
grep -Fxq 'install --cask --force claude-code@latest' "$log"
grep -Fxq 'claude-code@latest' "$fixture/installed-casks"
if grep -Fxq 'claude-code' "$fixture/installed-casks"; then
    echo 'Stable Claude Code cask survived latest-channel migration' >&2
    exit 1
fi

# A failed latest-channel install restores the stable cask rather than leaving
# Claude Code absent.
printf 'claude-code\n' >"$fixture/installed-casks"
if HOMEBREW_FAIL_LATEST=1 homebrew_bundle_install_resilient "$fixture/Brewfile"; then
    echo 'Expected a failed Claude Code migration to fail reconciliation' >&2
    exit 1
fi
grep -Fxq 'claude-code' "$fixture/installed-casks"

# Homebrew builds may read stdin. Each isolated upgrade must receive /dev/null
# so it cannot consume the remaining package names from the loop.
: >"$log"
homebrew_upgrade_individually
for package in first second third; do
    grep -Fxq "upgrade --formula $package" "$log"
done

printf 'Homebrew resilient reconciliation tests passed.\n'
