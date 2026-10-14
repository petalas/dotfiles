#!/usr/bin/env bash
# GitHub CLI remains an APT package, but follows GitHub's signed stable channel.

_linux_github_cli_key_matches() {
    local key_file=$1 actual
    local expected=6084d5d7bd8e288441e0e94fc6275570895da18e6751f70f057485dc2d1a811b
    [[ -f "$key_file" ]] || return 1
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$key_file") || return 1
    else
        actual=$(shasum -a 256 "$key_file") || return 1
    fi
    [[ "${actual%% *}" == "$expected" ]]
}

linux_github_cli_installed() {
    case "$(linux_distribution)" in
        debian|ubuntu)
            [[ $(dpkg-query -W -f='${Status}' gh 2>/dev/null) == 'install ok installed' ]]
            ;;
        *) return 1 ;;
    esac
}

linux_github_cli_prepare_repository() (
    local apt_root=${DOTFILES_APT_ROOT:-/etc/apt} architecture work_dir
    local key_file="$apt_root/keyrings/githubcli-archive-keyring.gpg"
    local source_file="$apt_root/sources.list.d/github-cli.list"
    case "$(linux_distribution)" in debian|ubuntu) ;; *) return 0 ;; esac
    architecture=$(dpkg --print-architecture) || return 1
    case "$architecture" in
        amd64|arm64|armhf|i386) ;;
        *) printf 'Unsupported GitHub CLI APT architecture: %s\n' "$architecture" >&2; return 1 ;;
    esac
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-gh-repository.XXXXXX") || return 1
    trap 'rm -rf -- "$work_dir"' EXIT

    if ! _linux_github_cli_key_matches "$key_file"; then
        download_file https://cli.github.com/packages/githubcli-archive-keyring.gpg "$work_dir/keyring.gpg" 65536 || return 1
        # SHA-256 published in cli/cli's official docs/install_linux.md. This
        # verifies the entire keyring, including both approved signing keys.
        if ! _linux_github_cli_key_matches "$work_dir/keyring.gpg"; then
            echo 'GitHub CLI signing-key checksum mismatch; repository not changed.' >&2
            return 1
        fi
        _linux_install_root_file "$work_dir/keyring.gpg" "$key_file" || return 1
    fi
    printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' \
        "$architecture" "$key_file" >"$work_dir/github-cli.list" || return 1
    if [[ ! -f "$source_file" ]] || _linux_files_differ "$source_file" "$work_dir/github-cli.list"; then
        _linux_install_root_file "$work_dir/github-cli.list" "$source_file" || return 1
    fi
)
