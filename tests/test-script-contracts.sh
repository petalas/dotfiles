#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-script-contracts.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home" "$fixture/config"

# The public dispatcher accepts only advertised installers and one argument.
installer_list=$("$repo_dir/install" list)
for installer_file in "$repo_dir"/installers/install_*.sh "$repo_dir"/installers/setup_*.sh; do
    installer_name=$(basename "$installer_file" .sh)
    installer_name=${installer_name#install_}
    installer_name=${installer_name#setup_}
    grep -Eq "(^|[[:space:]])$installer_name([[:space:]]|$)" <<<"$installer_list" || {
        echo "Installer is missing from the categorized list: $installer_name" >&2
        exit 1
    }
done
if "$repo_dir/install" _linux_as_root >/dev/null 2>&1; then
    echo "Internal helper was exposed as an installer." >&2
    exit 1
fi
if "$repo_dir/install" locale extra >/dev/null 2>&1; then
    echo "Installer dispatcher ignored extra arguments." >&2
    exit 1
fi
if zsh "$repo_dir/update-dotfiles" unexpected >/dev/null 2>&1; then
    echo "Update command ignored an unexpected argument." >&2
    exit 1
fi

# Existing Ghostty installations still receive Linux terminal configuration.
cat >"$fixture/bin/ghostty" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/bin/ghostty"
(
    export HOME="$fixture/home"
    export XDG_CONFIG_HOME="$fixture/config"
    export DOTFILES_OS_OVERRIDE=debian
    export PATH="$fixture/bin:/usr/bin:/bin"
    # shellcheck source=../installers/source_installers.sh
    source "$repo_dir/installers/source_installers.sh"
    install_ghostty
)
grep -Fxq com.mitchellh.ghostty.desktop "$fixture/config/xdg-terminals.list"

# A retained private SSH key can recreate a missing public key without input.
mkdir -p "$fixture/home/.ssh"
ssh-keygen -q -t ed25519 -N '' -C test@example.com -f "$fixture/home/.ssh/id_ed25519"
rm "$fixture/home/.ssh/id_ed25519.pub"
(
    export HOME="$fixture/home"
    unset DISPLAY WAYLAND_DISPLAY
    # shellcheck source=../installers/source_installers.sh
    source "$repo_dir/installers/source_installers.sh"
    setup_ssh_keys >/dev/null
)
[[ -s "$fixture/home/.ssh/id_ed25519.pub" ]]

# Invalid download tuning fails before any network command is attempted.
# shellcheck source=../lib/download.sh
source "$repo_dir/lib/download.sh"
if DOTFILES_DOWNLOAD_RETRIES=0 download_file https://example.invalid "$fixture/download"; then
    echo "Invalid download retry count was accepted." >&2
    exit 1
fi

# Downloaded installers receive their non-secret CLI arguments after the
# temporary script path (rustup uses this for its unattended profile/channel).
download_file() {
    cat >"$2" <<'EOF'
#!/usr/bin/env sh
output=$1
shift
printf '%s\n' "$@" >"$output"
EOF
}
run_downloaded_script sh https://example.invalid/installer \
    "$fixture/downloaded-script-args" alpha 'two words'
printf '%s\n' alpha 'two words' >"$fixture/expected-script-args"
cmp -s "$fixture/expected-script-args" "$fixture/downloaded-script-args"

printf 'Script interface contracts passed.\n'
