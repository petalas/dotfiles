#!/usr/bin/env bash
set -euo pipefail

mode="${1:?usage: state-manifest.sh record|compare MANIFEST}"
manifest="${2:?usage: state-manifest.sh record|compare MANIFEST}"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

managed_links=(
    "$HOME/.zshrc"
    "$HOME/.seashells.zsh"
    "$HOME/.p10k-seashells.zsh"
    "$HOME/.hushlogin"
    "$HOME/.gitconfig"
    "$HOME/git/work/.gitconfig"
    "$HOME/.tmux.conf"
    "$HOME/.config/ghostty/config.ghostty"
    "$HOME/.pi/agent/extensions/openai-fast-mode.ts"
    "$HOME/.pi/agent/themes/seashells.json"
    "$HOME/.config/yazi"
    "$HOME/.config/bat"
    "$HOME/.ssh/config.shared"
    "$HOME/.claude/CLAUDE.md"
)

if [[ -e "$repo_dir/dot/claude/settings.json" ]]; then
    managed_links+=("$HOME/.claude/settings.json")
fi
for command_file in "$repo_dir"/dot/claude/commands/*.md; do
    managed_links+=("$HOME/.claude/commands/$(basename "$command_file")")
done

assert_no_pending_links() {
    local path pending
    for path in "${managed_links[@]}"; do
        for pending in "$path".new.*; do
            [[ ! -e "$pending" && ! -L "$pending" ]] || {
                echo "unexpected pending managed link: $pending" >&2
                return 1
            }
        done
    done
}

generate_manifest() {
    local path
    for path in "${managed_links[@]}"; do
        [[ -L "$path" ]] || {
            echo "managed link disappeared: $path" >&2
            return 1
        }
        printf 'link\t%s\t%s\n' "${path#"$HOME"/}" "$(readlink "$path")"
        if [[ -L "$path.old" ]]; then
            printf 'backup-link\t%s.old\t%s\n' "${path#"$HOME"/}" "$(readlink "$path.old")"
        elif [[ -f "$path.old" ]]; then
            printf 'backup-file\t%s.old\t%s\t%s\n' \
                "${path#"$HOME"/}" "$(stat -c '%a' "$path.old")" \
                "$(sha256sum "$path.old" | awk '{print $1}')"
        elif [[ -e "$path.old" ]]; then
            echo "unsupported managed-link backup type: $path.old" >&2
            return 1
        fi
    done

    for path in "$HOME/.pi/agent/settings.json" "$HOME/.ssh/config"; do
        [[ -f "$path" ]] || {
            echo "managed file disappeared: $path" >&2
            return 1
        }
        printf 'file\t%s\t%s\t%s\n' \
            "${path#"$HOME"/}" "$(stat -c '%a' "$path")" "$(sha256sum "$path" | awk '{print $1}')"
    done

    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='package\t${binary:Package}\t${Version}\n' | LC_ALL=C sort
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Q | LC_ALL=C awk '{print "package\t" $1 "\t" $2}' | LC_ALL=C sort
    else
        echo "cannot snapshot packages: unsupported package manager" >&2
        return 1
    fi
}

assert_no_pending_links
case "$mode" in
    record)
        generate_manifest >"$manifest"
        ;;
    compare)
        current=$(mktemp /tmp/dotfiles-state.XXXXXX)
        trap 'rm -f "$current"' EXIT
        generate_manifest >"$current"
        if ! diff -u "$manifest" "$current"; then
            echo "managed state changed between the first and second install" >&2
            exit 1
        fi
        ;;
    *)
        echo "usage: state-manifest.sh record|compare MANIFEST" >&2
        exit 2
        ;;
esac
