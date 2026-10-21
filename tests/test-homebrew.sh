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
cat >"$fixture/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOMEBREW_TEST_LOG"
case "$*" in
    'bundle --no-upgrade --file='*) [[ "$*" != *"$HOMEBREW_MAIN_FILE"* ]] ;;
    'bundle list --tap '*) : ;;
    'bundle list --formula '*) printf '%s\n' working vendor/tap/tool ;;
    'bundle list --cask '*) printf '%s\n' claude-code@latest ;;
    'bundle check --file='*) exit 1 ;;
    'outdated --formula --quiet') printf '%s\n' first gh second third ;;
    'outdated --cask --quiet') printf '%s' "${HOMEBREW_OUTDATED_CASKS:-}" ;;
    'upgrade --'*)
        cat >/dev/null
        [[ "$*" != "upgrade --${HOMEBREW_UPGRADE_FAILURE:-}" ]]
        ;;
    *) exit 0 ;;
esac
EOF
cat >"$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$HOMEBREW_TEST_LOG"
[[ -z ${HOMEBREW_TEST_SUDO_DENIED:-} ]]
EOF
chmod +x "$fixture/bin/brew" "$fixture/bin/sudo"
PATH="$fixture/bin:/usr/bin:/bin"
docker_installer="$fixture/Docker.app/Contents/MacOS/install"
export PATH HOMEBREW_TEST_LOG="$log" HOMEBREW_MAIN_FILE="$fixture/Brewfile"
export DOCKER_DESKTOP_INSTALLER="$docker_installer" USER=tester
# shellcheck source=../lib/homebrew.sh
source "$repo_dir/lib/homebrew.sh"

entry="$fixture/trusted.entry"
_homebrew_extract_entry "$fixture/Brewfile" formula vendor/tap/tool "$entry"
grep -Fxq 'brew "vendor/tap/tool", trusted: true' "$entry"
homebrew_bundle_install_resilient "$fixture/Brewfile"
grep -Fq 'bundle list --formula' "$log"

# Homebrew builds may read stdin. Each isolated upgrade must receive /dev/null
# so it cannot consume the remaining package names from the loop.
: >"$log"
homebrew_upgrade_individually
for package in first gh second third; do
    grep -Fxq "upgrade --formula $package" "$log"
done

# A broken unrelated formula must not prevent GitHub CLI or later upgrades.
: >"$log"
if HOMEBREW_UPGRADE_FAILURE='formula first' homebrew_upgrade_individually; then
    echo 'Failed Homebrew upgrade was not reported' >&2
    exit 1
fi
for package in gh second third; do
    grep -Fxq "upgrade --formula $package" "$log"
done

# The cask upgrade deletes Docker's privileged helpers. Reinstalling them
# headlessly keeps Docker Desktop from asking for a password on next launch.
: >"$log"
HOMEBREW_OUTDATED_CASKS=$'slack\ndocker-desktop\n' homebrew_upgrade_individually
grep -Fxq 'upgrade --cask docker-desktop' "$log"
[[ $(grep -c ' config ' "$log") == 1 ]]
[[ $(tail -n 1 "$log") == "sudo -n $docker_installer config --user tester" ]]

# Other casks never touch Docker's privileged setup.
: >"$log"
HOMEBREW_OUTDATED_CASKS=$'slack\n' homebrew_upgrade_individually
if grep -q '^sudo ' "$log"; then exit 1; fi

# A failed Docker upgrade leaves the old helpers alone.
: >"$log"
if HOMEBREW_OUTDATED_CASKS=$'docker-desktop\n' HOMEBREW_UPGRADE_FAILURE='cask docker-desktop' \
    homebrew_upgrade_individually 2>/dev/null; then
    exit 1
fi
if grep -q '^sudo ' "$log"; then exit 1; fi

# Without passwordless sudo, Docker falls back to its own prompt; warn only.
: >"$log"
HOMEBREW_OUTDATED_CASKS=$'docker-desktop\n' HOMEBREW_TEST_SUDO_DENIED=1 \
    homebrew_upgrade_individually 2>"$fixture/stderr"
grep -Fq 'Docker Desktop will ask for an administrator password' "$fixture/stderr"

printf 'Homebrew resilient reconciliation tests passed.\n'
