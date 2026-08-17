#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-linux-packages.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
log="$fixture/commands"
export DOTFILES_PACKAGE_LOG="$log"

cat >"$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ "$1" != -n ]] || shift
exec "$@"
EOF
chmod +x "$fixture/bin/sudo"

# Installed apt-fast takes precedence over other APT frontends.
mkdir -p "$fixture/apt-fast-bin"
cat >"$fixture/apt-fast-bin/apt-fast" <<'EOF'
#!/usr/bin/env bash
printf 'apt-fast %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
if [[ " $* " == *' broken '* ]]; then
    exit 1
fi
if [[ "${DOTFILES_FAIL_ONCE:-0}" == 1 && ! -e "$DOTFILES_FAIL_ONCE_MARKER" ]]; then
    : >"$DOTFILES_FAIL_ONCE_MARKER"
    exit 1
fi
EOF
cat >"$fixture/apt-fast-bin/nala" <<'EOF'
#!/usr/bin/env bash
printf 'nala %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/apt-fast-bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/apt-fast-bin/debconf-set-selections" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
EOF
chmod +x "$fixture/apt-fast-bin"/*
: >"$log"
(
    export PATH="$fixture/apt-fast-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1
    export DOTFILES_OS_OVERRIDE=debian
    # shellcheck source=../lib/packages.sh
    source "$repo_dir/lib/packages.sh"
    linux_packages_install alpha beta
)
grep -Fxq 'apt-fast install -y alpha beta' "$log"
! grep -Fq 'nala ' "$log"

if (
    export PATH="$fixture/apt-fast-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1 DOTFILES_BATCH_RETRIES=0
    export DOTFILES_OS_OVERRIDE=debian
    source "$repo_dir/lib/packages.sh"
    linux_packages_install invalid-retry
); then
    echo "Expected an invalid retry count to fail" >&2
    exit 1
fi

# Retry a transient batch without discarding its parallelism.
: >"$log"
rm -f "$fixture/fail-once"
(
    export PATH="$fixture/apt-fast-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1 DOTFILES_BATCH_RETRIES=2
    export DOTFILES_BATCH_RETRY_DELAY_SECONDS=0 DOTFILES_FAIL_ONCE=1
    export DOTFILES_FAIL_ONCE_MARKER="$fixture/fail-once"
    export DOTFILES_OS_OVERRIDE=debian
    source "$repo_dir/lib/packages.sh"
    linux_packages_install alpha beta
)
[[ "$(grep -c '^apt-fast install -y alpha beta$' "$log")" == 2 ]]

# A permanent failure is isolated only after the full batch fails. Unrelated
# packages continue in multi-package batches and the aggregate result fails.
: >"$log"
if (
    export PATH="$fixture/apt-fast-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1 DOTFILES_BATCH_RETRIES=1
    export DOTFILES_BATCH_RETRY_DELAY_SECONDS=0
    export DOTFILES_OS_OVERRIDE=debian
    source "$repo_dir/lib/packages.sh"
    linux_packages_install alpha broken gamma delta
); then
    echo "Expected a broken apt-fast package to propagate failure" >&2
    exit 1
fi
grep -Fxq 'apt-fast install -y alpha broken gamma delta' "$log"
grep -Fxq 'apt-fast install -y gamma' "$log"
grep -Fxq 'apt-fast install -y broken' "$log"

# The same helper is sourced by the zsh `upd` function.
if command -v zsh >/dev/null 2>&1; then
    : >"$log"
    PATH="$fixture/apt-fast-bin:$fixture/bin:/usr/bin:/bin" \
        DOTFILES_PACKAGE_NO_SUDO=1 DOTFILES_OS_OVERRIDE=debian \
        zsh -c 'source "$1"; linux_packages_install zeta' \
        zsh "$repo_dir/lib/packages.sh"
    grep -Fxq 'apt-fast install -y zeta' "$log"
fi

# A fresh machine adds apt-fast's signed PPA source, pre-seeds debconf before
# installation, and enforces the same concurrency in apt-fast.conf.
mkdir -p "$fixture/apt-bootstrap-bin" "$fixture/apt-bootstrap"
cat >"$fixture/apt-fast-template" <<'EOF'
#!/usr/bin/env bash
printf 'apt-fast %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/apt-bootstrap-bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
if [[ "$*" == 'install -y apt-fast aria2' ]]; then
    cp "$DOTFILES_APT_FAST_TEMPLATE" "$(dirname "$0")/apt-fast"
    chmod +x "$(dirname "$0")/apt-fast"
    cat >"$DOTFILES_APT_FAST_CONFIG" <<'CONFIG'
_MAXNUM=5
_MAXCONPERSRV=10
CONFIG
fi
EOF
cat >"$fixture/apt-bootstrap-bin/curl" <<'EOF'
#!/usr/bin/env bash
destination=""
while (($#)); do
    if [[ "$1" == -o ]]; then destination="$2"; shift 2; else shift; fi
done
if [[ -n "$destination" ]]; then
    printf 'signed apt-fast key\n' >"$destination"
else
    printf 'signed apt-fast key\n'
fi
EOF
cat >"$fixture/apt-bootstrap-bin/gpg" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == --show-keys ]]; then
    printf 'fpr:::::::::BC5934FD3DEBD4DAEA544F791E2824A7F22B44BD:\n'
else
    cat
fi
EOF
cat >"$fixture/apt-bootstrap-bin/debconf-set-selections" <<'EOF'
#!/usr/bin/env bash
while IFS= read -r selection; do
    printf 'debconf %s\n' "$selection" >>"$DOTFILES_PACKAGE_LOG"
done
EOF
cat >"$fixture/apt-bootstrap-bin/apt-cache" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$fixture/apt-bootstrap-bin"/*
: >"$log"
(
    export PATH="$fixture/apt-bootstrap-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1 DOTFILES_BATCH_RETRIES=1
    export DOTFILES_SKIP_APT_FAST_DETECTION=1
    export DOTFILES_APT_ROOT="$fixture/apt-bootstrap"
    export DOTFILES_APT_FAST_CONFIG="$fixture/apt-bootstrap/apt-fast.conf"
    export DOTFILES_APT_FAST_TEMPLATE="$fixture/apt-fast-template"
    export DOTFILES_OS_OVERRIDE=ubuntu
    export DOTFILES_OS_CODENAME_OVERRIDE=noble
    source "$repo_dir/lib/packages.sh"
    linux_packages_install gamma
)
grep -Fxq 'apt-get install -y apt-fast aria2' "$log"
grep -Fxq 'debconf debconf apt-fast/maxdownloads string 8' "$log"
[[ "$(grep -n 'debconf apt-fast/maxdownloads' "$log" | cut -d: -f1)" -lt \
    "$(grep -n 'apt-get install -y apt-fast aria2' "$log" | cut -d: -f1)" ]]
grep -Fxq 'debconf debconf apt-fast/dlflag boolean true' "$log"
grep -Fxq 'debconf debconf apt-fast/aptmanager string apt-get' "$log"
grep -Fxq 'apt-fast install -y gamma' "$log"
grep -Fq 'Suites: noble' "$fixture/apt-bootstrap/sources.list.d/apt-fast.sources"
grep -Fq "Signed-By: $fixture/apt-bootstrap/keyrings/apt-fast.gpg" \
    "$fixture/apt-bootstrap/sources.list.d/apt-fast.sources"
grep -Fxq '_MAXNUM=8' "$fixture/apt-bootstrap/apt-fast.conf"
grep -Fxq '_MAXCONPERSRV=8' "$fixture/apt-bootstrap/apt-fast.conf"

# An unavailable PPA leaves the existing distro-provided Nala usable.
mkdir -p "$fixture/nala-fallback-bin" "$fixture/nala-apt"
cat >"$fixture/nala-fallback-bin/nala" <<'EOF'
#!/usr/bin/env bash
printf 'nala %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/nala-fallback-bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
exit 1
EOF
cp "$fixture/apt-bootstrap-bin/curl" "$fixture/apt-bootstrap-bin/gpg" \
    "$fixture/apt-bootstrap-bin/debconf-set-selections" "$fixture/nala-fallback-bin/"
chmod +x "$fixture/nala-fallback-bin"/*
: >"$log"
(
    export PATH="$fixture/nala-fallback-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1 DOTFILES_BATCH_RETRIES=1
    export DOTFILES_SKIP_APT_FAST_DETECTION=1
    export DOTFILES_APT_ROOT="$fixture/nala-apt"
    export DOTFILES_OS_OVERRIDE=debian
    source "$repo_dir/lib/packages.sh"
    linux_packages_install fallback
)
grep -Fxq 'nala install -y fallback' "$log"
[[ ! -e "$fixture/nala-apt/sources.list.d/apt-fast.sources" ]]

# Pacman parallelism is configured before package installation.
mkdir -p "$fixture/pacman-bin" "$fixture/pacman"
cat >"$fixture/pacman-bin/pacman" <<'EOF'
#!/usr/bin/env bash
printf 'pacman %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
[[ " $* " != *' broken '* ]]
EOF
chmod +x "$fixture/pacman-bin/pacman"
cat >"$fixture/pacman/pacman.conf" <<'EOF'
[options]
#ParallelDownloads = 5

[core]
Include = /etc/pacman.d/mirrorlist
EOF
: >"$log"
(
    export PATH="$fixture/pacman-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1
    export DOTFILES_PACMAN_CONF="$fixture/pacman/pacman.conf"
    export DOTFILES_OS_OVERRIDE=arch
    source "$repo_dir/lib/packages.sh"
    linux_packages_install delta
)
grep -Fxq 'ParallelDownloads = 8' "$fixture/pacman/pacman.conf"
grep -Fxq 'pacman -S --noconfirm --needed delta' "$log"

: >"$log"
if (
    export PATH="$fixture/pacman-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1 DOTFILES_BATCH_RETRIES=1
    export DOTFILES_BATCH_RETRY_DELAY_SECONDS=0
    export DOTFILES_PACMAN_CONF="$fixture/pacman/pacman.conf"
    export DOTFILES_OS_OVERRIDE=arch
    source "$repo_dir/lib/packages.sh"
    linux_packages_install one broken two three
); then
    echo "Expected a broken pacman package to propagate failure" >&2
    exit 1
fi
grep -Fxq 'pacman -S --noconfirm --needed one broken two three' "$log"
grep -Fxq 'pacman -S --noconfirm --needed two' "$log"
grep -Fxq 'pacman -S --noconfirm --needed broken' "$log"

# netselect-apt chooses the Debian archive mirror while security and third-party
# repositories stay untouched. A state marker prevents rerating every run.
mkdir -p "$fixture/debian-bin" "$fixture/apt/sources.list.d"
cat >"$fixture/debian-bin/apt-fast" <<'EOF'
#!/usr/bin/env bash
printf 'apt-fast %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/debian-bin/debconf-set-selections" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
EOF
cat >"$fixture/debian-bin/netselect-apt" <<'EOF'
#!/usr/bin/env bash
printf 'netselect-apt %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
outfile=""
while (($#)); do
    if [[ "$1" == -o ]]; then outfile="$2"; shift 2; else shift; fi
done
cat >"$outfile" <<'SOURCES'
deb http://fast.example/debian/ trixie main
SOURCES
EOF
chmod +x "$fixture/debian-bin"/*
cat >"$fixture/apt/sources.list.d/debian.sources" <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main
EOF
cat >"$fixture/apt/sources.list" <<'EOF'
deb https://packages.example.invalid/debian stable main
EOF
: >"$log"
(
    export PATH="$fixture/debian-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1
    export DOTFILES_APT_ROOT="$fixture/apt"
    export DOTFILES_OS_OVERRIDE=debian
    export DOTFILES_OS_CODENAME_OVERRIDE=trixie
    source "$repo_dir/lib/packages.sh"
    linux_packages_optimize_mirrors
    linux_packages_optimize_mirrors
)
grep -Fq 'URIs: http://fast.example/debian' "$fixture/apt/sources.list.d/debian.sources"
grep -Fq 'URIs: http://security.debian.org/debian-security' "$fixture/apt/sources.list.d/debian.sources"
grep -Fq 'https://packages.example.invalid/debian' "$fixture/apt/sources.list"
grep -Fq 'URIs: http://deb.debian.org/debian' \
    "$fixture/apt/.dotfiles-backups/sources.list.d__debian.sources"
[[ "$(grep -c '^netselect-apt ' "$log")" == 1 ]]

# Reflector atomically replaces Arch's mirror list once and retains a backup.
mkdir -p "$fixture/reflector-bin" "$fixture/pacman.d"
cat >"$fixture/reflector-bin/pacman" <<'EOF'
#!/usr/bin/env bash
printf 'pacman %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/reflector-bin/reflector" <<'EOF'
#!/usr/bin/env bash
printf 'reflector %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
outfile=""
while (($#)); do
    if [[ "$1" == --save ]]; then outfile="$2"; shift 2; else shift; fi
done
printf 'Server = https://mirror.example/$repo/os/$arch\n' >"$outfile"
EOF
chmod +x "$fixture/reflector-bin"/*
printf '[options]\n' >"$fixture/pacman/reflector.conf"
printf 'Server = https://old.example/$repo/os/$arch\n' >"$fixture/pacman.d/mirrorlist"
: >"$log"
(
    export PATH="$fixture/reflector-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1
    export DOTFILES_PACMAN_CONF="$fixture/pacman/reflector.conf"
    export DOTFILES_PACMAN_MIRRORLIST="$fixture/pacman.d/mirrorlist"
    export DOTFILES_PACMAN_MIRROR_STATE="$fixture/pacman.d/.dotfiles-reflector"
    export DOTFILES_OS_OVERRIDE=arch
    export DOTFILES_OS_RAW_OVERRIDE=arch
    source "$repo_dir/lib/packages.sh"
    linux_packages_optimize_mirrors
    linux_packages_optimize_mirrors
)
grep -Fq 'Server = https://mirror.example/$repo/os/$arch' "$fixture/pacman.d/mirrorlist"
grep -Fq 'Server = https://old.example/$repo/os/$arch' "$fixture/pacman.d/mirrorlist.dotfiles-backup"
[[ "$(grep -c '^reflector ' "$log")" == 1 ]]

if grep -Rqi flatpak \
    "$repo_dir/linux-deps.sh" "$repo_dir/installers" "$repo_dir/dot/zshrc"; then
    echo "Flatpak references remain in Linux setup or update paths." >&2
    exit 1
fi

echo "Linux package helper tests passed."
