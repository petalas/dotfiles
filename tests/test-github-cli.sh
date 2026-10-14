#!/usr/bin/env bash
# Exercise the public package facade without touching host APT configuration.
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-github-cli.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/tmp" "$fixture/apt"
export GH_TEST_LOG="$fixture/commands" GH_TEST_VERSION="$fixture/version"
export GH_TEST_REAL_INSTALL
GH_TEST_REAL_INSTALL=$(command -v install)
export DOTFILES_APT_ROOT="$fixture/apt" DOTFILES_PACKAGE_NO_SUDO=1
export DOTFILES_OS_OVERRIDE=debian DOTFILES_BATCH_RETRIES=1
export TMPDIR="$fixture/tmp" DOTFILES_APT_FAST_CONFIG="$fixture/apt-fast.conf"

cat >"$fixture/bin/apt-fast" <<'EOF'
#!/usr/bin/env bash
printf 'apt-fast %s\n' "$*" >>"$GH_TEST_LOG"
if [[ "$*" == 'install -y gh' ]]; then
    [[ -s "$DOTFILES_APT_ROOT/keyrings/githubcli-archive-keyring.gpg" ]] || exit 21
    [[ -s "$DOTFILES_APT_ROOT/sources.list.d/github-cli.list" ]] || exit 22
    printf '2.102.0\n' >"$GH_TEST_VERSION"
fi
EOF
cat >"$fixture/bin/debconf-set-selections" <<'EOF'
#!/usr/bin/env bash
while IFS= read -r _line; do :; done
EOF
cat >"$fixture/bin/dpkg" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == --print-architecture ]] || exit 2
printf '%s\n' "${GH_TEST_ARCH:-amd64}"
EOF
cat >"$fixture/bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == '-W -f=${Status} gh' ]] || exit 2
[[ "${GH_TEST_INSTALLED:-1}" == 1 ]] || exit 1
printf 'install ok installed\n'
EOF
cat >"$fixture/bin/curl" <<'EOF'
#!/usr/bin/env bash
destination=
url=
maximum_size=
while (($#)); do
    case "$1" in
        -o) destination=$2; shift 2 ;;
        --max-filesize) maximum_size=$2; shift 2 ;;
        https://*) url=$1; shift ;;
        *) shift ;;
    esac
done
[[ "$url" == https://cli.github.com/packages/githubcli-archive-keyring.gpg ]] || exit 2
[[ "$maximum_size" == 65536 ]] || { echo 'Signing-key download needs a 64 KiB limit' >&2; exit 3; }
printf 'download keyring\n' >>"$GH_TEST_LOG"
printf '%s\n' "${GH_TEST_KEY:-verified fixture keyring}" >"$destination"
[[ "${GH_TEST_DOWNLOAD_FAIL:-0}" == 0 ]]
EOF
cat >"$fixture/bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
IFS= read -r key <"$1"
if [[ "$key" == 'verified fixture keyring' ]]; then
    printf '6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b  %s\n' "$1"
else
    printf '0000000000000000000000000000000000000000000000000000000000000000  %s\n' "$1"
fi
EOF
cat >"$fixture/bin/install" <<'EOF'
#!/usr/bin/env bash
[[ "$4" != "${GH_TEST_FAIL_DESTINATION:-}" ]] || exit 23
exec "$GH_TEST_REAL_INSTALL" "$@"
EOF
chmod +x "$fixture/bin"/*
export PATH="$fixture/bin:/usr/bin:/bin"
# shellcheck source=../lib/packages.sh
source "$repo_dir/lib/packages.sh"

linux_packages_install gh
[[ $(<"$GH_TEST_VERSION") == 2.102.0 ]]
grep -Fxq "deb [arch=amd64 signed-by=$DOTFILES_APT_ROOT/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    "$DOTFILES_APT_ROOT/sources.list.d/github-cli.list"
grep -Fxq 'apt-fast update' "$GH_TEST_LOG"
grep -Fxq 'apt-fast install -y gh' "$GH_TEST_LOG"
[[ $(grep -n '^apt-fast update$' "$GH_TEST_LOG" | cut -d: -f1) -lt \
    $(grep -n '^apt-fast install -y gh$' "$GH_TEST_LOG" | cut -d: -f1) ]]
[[ -z $(find "$fixture/tmp" -mindepth 1 -print -quit) ]]

# Repeated installation reuses the verified keyring. A partial previous run
# with only the keyring is repaired without another download.
linux_packages_install gh
[[ $(grep -c '^download keyring$' "$GH_TEST_LOG") == 1 ]]
rm "$DOTFILES_APT_ROOT/sources.list.d/github-cli.list"
GH_TEST_ARCH=arm64 linux_packages_install gh
grep -Fq 'arch=arm64 ' "$DOTFILES_APT_ROOT/sources.list.d/github-cli.list"
[[ $(grep -c '^download keyring$' "$GH_TEST_LOG") == 1 ]]
DOTFILES_OS_OVERRIDE=ubuntu GH_TEST_ARCH=armhf linux_packages_install gh
grep -Fq 'arch=armhf ' "$DOTFILES_APT_ROOT/sources.list.d/github-cli.list"
[[ $(grep -c '^download keyring$' "$GH_TEST_LOG") == 1 ]]

# Existing untrusted bytes cannot become APT trust. Neither root file changes
# after checksum or download failure, and no package installation follows.
key_file="$DOTFILES_APT_ROOT/keyrings/githubcli-archive-keyring.gpg"
source_file="$DOTFILES_APT_ROOT/sources.list.d/github-cli.list"
printf 'old keyring\n' >"$key_file"
cp "$key_file" "$fixture/previous-key"
cp "$source_file" "$fixture/previous-source"
: >"$GH_TEST_LOG"
linux_packages_install unrelated
if grep -Fxq 'download keyring' "$GH_TEST_LOG"; then
    echo 'Unrelated packages triggered GitHub CLI repository setup' >&2
    exit 1
fi
cmp -s "$key_file" "$fixture/previous-key"
: >"$GH_TEST_LOG"
if GH_TEST_KEY=untrusted linux_packages_install gh >"$fixture/out" 2>"$fixture/err"; then
    echo 'Untrusted GitHub CLI signing key was accepted' >&2
    exit 1
fi
grep -Fq 'signing-key checksum mismatch' "$fixture/err"
cmp -s "$key_file" "$fixture/previous-key"
cmp -s "$source_file" "$fixture/previous-source"
if grep -Fq 'apt-fast install' "$GH_TEST_LOG"; then
    echo 'Package installation ran after signing-key validation failed' >&2
    exit 1
fi
if GH_TEST_DOWNLOAD_FAIL=1 linux_packages_install gh; then
    echo 'Failed keyring download was accepted' >&2
    exit 1
fi
cmp -s "$key_file" "$fixture/previous-key"
cmp -s "$source_file" "$fixture/previous-source"
[[ -z $(find "$fixture/tmp" -mindepth 1 -print -quit) ]]

# A late root-write failure leaves the new verified keyring usable. Re-running
# converges to complete configuration and the current package.
rm "$source_file"
if GH_TEST_FAIL_DESTINATION="$source_file" linux_packages_install gh; then
    echo 'Failed repository source write was accepted' >&2
    exit 1
fi
[[ ! -e "$source_file" ]]
[[ $(<"$key_file") == 'verified fixture keyring' ]]
[[ -z $(find "$fixture/tmp" -mindepth 1 -print -quit) ]]
linux_packages_install gh
[[ $(<"$GH_TEST_VERSION") == 2.102.0 ]]
[[ -s "$source_file" ]]

# Test the portable hash fallback using a restricted PATH without sha256sum.
mkdir "$fixture/shasum-bin"
for command in dpkg dpkg-query curl apt-fast debconf-set-selections install; do
    ln -s "$fixture/bin/$command" "$fixture/shasum-bin/$command"
done
for command in bash dirname mkdir mktemp rm cmp wc env; do
    ln -s "$(command -v "$command")" "$fixture/shasum-bin/$command"
done
cat >"$fixture/shasum-bin/shasum" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -a && "$2" == 256 ]] || exit 2
shift 2
exec "$GH_TEST_HASH_FIXTURE" "$@"
EOF
chmod +x "$fixture/shasum-bin/shasum"
export GH_TEST_HASH_FIXTURE="$fixture/bin/sha256sum"
rm "$key_file"
PATH="$fixture/shasum-bin" linux_packages_install gh
[[ $(<"$key_file") == 'verified fixture keyring' ]]

# Unsupported architectures and non-APT platforms do not write repository
# configuration. The installed-package probe distinguishes absence and distro.
: >"$GH_TEST_LOG"
if GH_TEST_ARCH=riscv64 linux_packages_install gh; then
    echo 'Unsupported APT architecture was accepted' >&2
    exit 1
fi
[[ ! -s "$GH_TEST_LOG" ]]
linux_github_cli_installed
if GH_TEST_INSTALLED=0 linux_github_cli_installed; then
    echo 'Missing GitHub CLI package was reported installed' >&2
    exit 1
fi
for os in arch macos; do
    DOTFILES_OS_OVERRIDE="$os" linux_github_cli_prepare_repository
    if DOTFILES_OS_OVERRIDE="$os" linux_github_cli_installed; then
        echo "Non-APT $os installation was treated as a Debian package" >&2
        exit 1
    fi
done
[[ ! -s "$GH_TEST_LOG" ]]

# The same package facade is used by upd under Zsh.
if command -v zsh >/dev/null 2>&1; then
    zsh -c 'source "$1"; linux_github_cli_installed; linux_packages_install gh' \
        zsh "$repo_dir/lib/packages.sh"
    grep -Fxq 'apt-fast install -y gh' "$GH_TEST_LOG"
fi

printf 'GitHub CLI package source tests passed.\n'
