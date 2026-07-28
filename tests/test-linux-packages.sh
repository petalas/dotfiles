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
EOF
cat >"$fixture/apt-fast-bin/nala" <<'EOF'
#!/usr/bin/env bash
printf 'nala %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/apt-fast-bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
chmod +x "$fixture/apt-fast-bin"/*
: >"$log"
(
    export PATH="$fixture/apt-fast-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1
    os_id=debian
    # shellcheck source=../lib/packages.sh
    source "$repo_dir/lib/packages.sh"
    linux_packages_install alpha beta
)
grep -Fxq 'apt-fast install -y alpha beta' "$log"
! grep -Fq 'nala ' "$log"

# The same helper is sourced by the zsh `upd` function.
if command -v zsh >/dev/null 2>&1; then
    : >"$log"
    PATH="$fixture/apt-fast-bin:$fixture/bin:/usr/bin:/bin" \
        DOTFILES_PACKAGE_NO_SUDO=1 \
        zsh -c 'os_id=debian; source "$1"; linux_packages_install zeta' \
        zsh "$repo_dir/lib/packages.sh"
    grep -Fxq 'apt-fast install -y zeta' "$log"
fi

# If no fast frontend exists, install Nala from the distro repository once,
# then use it for the requested transaction.
mkdir -p "$fixture/nala-bootstrap-bin"
cat >"$fixture/nala-template" <<'EOF'
#!/usr/bin/env bash
printf 'nala %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
EOF
cat >"$fixture/nala-bootstrap-bin/apt-cache" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == show && "$2" == nala ]]
EOF
cat >"$fixture/nala-bootstrap-bin/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
if [[ "$*" == 'install -y nala' ]]; then
    cp "$DOTFILES_NALA_TEMPLATE" "$(dirname "$0")/nala"
    chmod +x "$(dirname "$0")/nala"
fi
EOF
chmod +x "$fixture/nala-bootstrap-bin"/*
: >"$log"
(
    export PATH="$fixture/nala-bootstrap-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1
    export DOTFILES_NALA_TEMPLATE="$fixture/nala-template"
    os_id=ubuntu
    source "$repo_dir/lib/packages.sh"
    linux_packages_install gamma
)
grep -Fxq 'apt-get update' "$log"
grep -Fxq 'apt-get install -y nala' "$log"
grep -Fxq 'nala install -y gamma' "$log"

# Pacman parallelism is configured before package installation.
mkdir -p "$fixture/pacman-bin" "$fixture/pacman"
cat >"$fixture/pacman-bin/pacman" <<'EOF'
#!/usr/bin/env bash
printf 'pacman %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
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
    export DOTFILES_PACMAN_PARALLEL_DOWNLOADS=24
    os_id=arch
    source "$repo_dir/lib/packages.sh"
    linux_packages_install delta
)
grep -Fxq 'ParallelDownloads = 24' "$fixture/pacman/pacman.conf"
grep -Fxq 'pacman -Syu --noconfirm --needed delta' "$log"

: >"$log"
(
    export PATH="$fixture/pacman-bin:$fixture/bin:/usr/bin:/bin"
    export DOTFILES_PACKAGE_NO_SUDO=1
    export DOTFILES_PACMAN_CONF="$fixture/pacman/pacman.conf"
    export DOTFILES_INTEGRATION_TEST=1
    os_id=arch
    source "$repo_dir/lib/packages.sh"
    linux_packages_install epsilon
)
grep -Fxq 'pacman --disable-sandbox -Syu --noconfirm --needed epsilon' "$log"

# netselect-apt chooses the Debian archive mirror while security and third-party
# repositories stay untouched. A state marker prevents rerating every run.
mkdir -p "$fixture/debian-bin" "$fixture/apt/sources.list.d"
cat >"$fixture/debian-bin/nala" <<'EOF'
#!/usr/bin/env bash
printf 'nala %s\n' "$*" >>"$DOTFILES_PACKAGE_LOG"
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
    os_id=debian
    os_version_codename=trixie
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
    os_id=arch
    os_id_raw=arch
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
