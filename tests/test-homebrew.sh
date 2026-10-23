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
    'outdated --json=v2')
        outdated() {
            printf '%s\n' "$@" | jq -Rn '[inputs | select(length > 0)
                | {name: ., installed_versions: ["1.0"], current_version: "2.0", pinned: (. == "pinned")}]'
        }
        jq -n --argjson formulae "$(outdated first gh second third pinned)" \
            --argjson casks "$(outdated ${HOMEBREW_OUTDATED_CASKS:-})" '{$formulae, $casks}'
        ;;
    'list --formula --installed-on-request') printf '%s\n' gh current ;;
    'list --formula --versions') printf '%s\n' 'first 1.0' 'gh 1.0' 'current 3.0' 'dependency 4.0' ;;
    'list --cask --versions') printf '%s\n' 'zed 0.9' ;;
    'list --cask '*) grep -Fxq "$3" "${HOMEBREW_INSTALLED_CASKS:-/dev/null}" ;;
    'install --cask --adopt t3-code@nightly') [[ -z ${HOMEBREW_INSTALL_FAILS:-} ]] ;;
    'upgrade --'*)
        cat >/dev/null
        # Homebrew reopens an app it quit, racing the helper restore.
        [[ "$*" != 'upgrade --cask docker-desktop' || ! -e "$DOCKER_TEST_RUNNING" ]] || exit 1
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
cat >"$fixture/bin/osascript" <<'EOF'
#!/usr/bin/env bash
[[ "$2" == *'is running' ]] || exit 1
if [[ -e "$DOCKER_TEST_RUNNING" ]]; then echo true; else echo false; fi
EOF
cat >"$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >>"$HOMEBREW_TEST_LOG"
[[ "$1 $2" == 'desktop stop' && -z ${DOCKER_TEST_STUCK:-} ]] || exit 1
rm -f "$DOCKER_TEST_RUNNING"
EOF
cat >"$fixture/bin/open" <<'EOF'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >>"$HOMEBREW_TEST_LOG"
EOF
chmod +x "$fixture/bin/brew" "$fixture/bin/sudo" "$fixture/bin/osascript" \
    "$fixture/bin/docker" "$fixture/bin/open"
# Outdated entries are JSON; the restricted PATH below omits Homebrew's bin.
ln -s "$(command -v jq)" "$fixture/bin/jq"
PATH="$fixture/bin:/usr/bin:/bin"
docker_installer="$fixture/Docker.app/Contents/MacOS/install"
export PATH HOMEBREW_TEST_LOG="$log" HOMEBREW_MAIN_FILE="$fixture/Brewfile"
export DOCKER_DESKTOP_INSTALLER="$docker_installer" USER=tester
export DOCKER_TEST_RUNNING="$fixture/docker-running"
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
homebrew_upgrade_individually >"$fixture/results"
for package in first gh second third; do
    grep -Fxq "upgrade --formula $package" "$log"
done
# One line per outdated entry, requested formula, and cask; pinned formulae are
# left alone and unchanged dependencies are not listed.
grep -Fxq 'Upgraded gh 1.0 ==> 2.0' "$fixture/results"
grep -Fxq 'current 3.0 ==> already latest' "$fixture/results"
grep -Fxq 'zed 0.9 ==> already latest' "$fixture/results"
grep -Fxq 'pinned 1.0 ==> skipped' "$fixture/results"
if grep -Fq 'upgrade --formula pinned' "$log" || grep -Fq dependency "$fixture/results"; then
    echo 'Pinned or unchanged dependency entries were handled as upgrades' >&2
    exit 1
fi
[[ $(grep -c '^Upgraded gh ' "$fixture/results") == 1 ]]

# A broken unrelated formula must not prevent GitHub CLI or later upgrades.
: >"$log"
if HOMEBREW_UPGRADE_FAILURE='formula first' homebrew_upgrade_individually >"$fixture/results" 2>/dev/null; then
    echo 'Failed Homebrew upgrade was not reported' >&2
    exit 1
fi
grep -Fxq 'first 1.0 ==> failed to update' "$fixture/results"
for package in gh second third; do
    grep -Fxq "upgrade --formula $package" "$log"
done

# The cask upgrade deletes Docker's privileged helpers. Reinstalling them
# headlessly keeps Docker Desktop from asking for a password on next launch.
: >"$log"
HOMEBREW_OUTDATED_CASKS=$'slack\ndocker-desktop\n' homebrew_upgrade_individually >/dev/null
grep -Fxq 'upgrade --cask docker-desktop' "$log"
[[ $(grep -c ' config ' "$log") == 1 ]]
# The helpers are restored right after Docker's upgrade, before the next entry.
awk -v expected="sudo -n $docker_installer config --user tester" '
    $0 == "upgrade --cask docker-desktop" { docker = 1; next }
    docker && /^upgrade / { exit }
    docker && $0 == expected { found = 1 }
    END { exit !found }
' "$log"

# A running Docker is quit before the upgrade so Homebrew cannot reopen it
# while the helpers are missing, and it is reopened after the restore.
: >"$log"
touch "$DOCKER_TEST_RUNNING"
HOMEBREW_OUTDATED_CASKS=$'docker-desktop\n' homebrew_upgrade_individually >/dev/null
grep -Ev '^(outdated|list|upgrade --formula) ' "$log" | diff - <(printf '%s\n' 'docker desktop stop --timeout 60' \
    'upgrade --cask docker-desktop' 'sudo -n true' \
    "sudo -n $docker_installer config --user tester" 'open -b com.docker.docker')

# If Docker will not quit, its upgrade is skipped rather than raced.
: >"$log"
touch "$DOCKER_TEST_RUNNING"
if HOMEBREW_OUTDATED_CASKS=$'docker-desktop\n' DOCKER_TEST_STUCK=1 \
    homebrew_upgrade_individually >"$fixture/results" 2>/dev/null; then
    exit 1
fi
grep -Fxq 'docker-desktop 1.0 ==> failed to update' "$fixture/results"
if grep -Eq '^(upgrade --cask docker-desktop|open )' "$log"; then exit 1; fi
rm -f "$DOCKER_TEST_RUNNING"

# Other casks never touch Docker's privileged setup.
: >"$log"
HOMEBREW_OUTDATED_CASKS=$'slack\n' homebrew_upgrade_individually >/dev/null
if grep -q '^sudo ' "$log"; then exit 1; fi

# A failed Docker upgrade leaves the old helpers alone.
: >"$log"
if HOMEBREW_OUTDATED_CASKS=$'docker-desktop\n' HOMEBREW_UPGRADE_FAILURE='cask docker-desktop' \
    homebrew_upgrade_individually >/dev/null 2>&1; then
    exit 1
fi
if grep -q '^sudo ' "$log"; then exit 1; fi

# Without passwordless sudo, Docker falls back to its own prompt; warn only.
: >"$log"
HOMEBREW_OUTDATED_CASKS=$'docker-desktop\n' HOMEBREW_TEST_SUDO_DENIED=1 \
    homebrew_upgrade_individually >/dev/null 2>"$fixture/stderr"
grep -Fq 'Docker Desktop will ask for an administrator password' "$fixture/stderr"

# Machines registered with the T3 Code Beta cask move to Nightly: install it
# first (adopting a hand-installed bundle), then drop the Beta registration.
printf 'cask "t3-code@nightly"\n' >"$fixture/t3.Brewfile"
printf 't3-code\n' >"$fixture/installed-casks"
: >"$log"
HOMEBREW_INSTALLED_CASKS="$fixture/installed-casks" \
    homebrew_bundle_install_resilient "$fixture/t3.Brewfile" >/dev/null
grep -E '^(install|uninstall|bundle --no-upgrade) ' "$log" | diff - <(printf '%s\n' \
    'install --cask --adopt t3-code@nightly' 'uninstall --cask --force t3-code' \
    "bundle --no-upgrade --file=$fixture/t3.Brewfile")

# A failed Nightly install keeps Beta and is reported, but reconciliation of
# the other entries still runs.
: >"$log"
if HOMEBREW_INSTALLED_CASKS="$fixture/installed-casks" HOMEBREW_INSTALL_FAILS=1 \
    homebrew_bundle_install_resilient "$fixture/t3.Brewfile" >/dev/null 2>&1; then
    exit 1
fi
if grep -q '^uninstall ' "$log"; then exit 1; fi
grep -Fxq "bundle --no-upgrade --file=$fixture/t3.Brewfile" "$log"

# With Nightly already registered, only the Beta registration is removed.
printf '%s\n' t3-code t3-code@nightly >"$fixture/installed-casks"
: >"$log"
HOMEBREW_INSTALLED_CASKS="$fixture/installed-casks" \
    homebrew_bundle_install_resilient "$fixture/t3.Brewfile" >/dev/null
if grep -q '^install ' "$log"; then exit 1; fi
grep -Fxq 'uninstall --cask --force t3-code' "$log"

# Machines without the Beta cask leave Nightly to normal reconciliation.
: >"$log"
homebrew_bundle_install_resilient "$fixture/t3.Brewfile" >/dev/null
if grep -Eq '^(install|uninstall) ' "$log"; then exit 1; fi

printf 'Homebrew resilient reconciliation tests passed.\n'
