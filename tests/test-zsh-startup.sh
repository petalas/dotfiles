#!/usr/bin/env bash
set -euo pipefail

command -v zsh >/dev/null 2>&1 || {
    echo "Zsh is unavailable; skipping startup test."
    exit 0
}
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-zsh-startup.XXXXXX)
trap 'rm -rf "$fixture"' EXIT

HOME="$fixture" PATH=/usr/bin:/bin zsh -dfc '
    source "$1"
    (( $+functions[upd] ))
    (( $+functions[y] ))
    (( $+functions[kill-port] ))
' zsh "$repo_dir/dot/zshrc" 2>"$fixture/stderr"
if grep -Eqi 'no such file|command not found' "$fixture/stderr"; then
    cat "$fixture/stderr" >&2
    exit 1
fi
printf 'Zsh startup guards passed.\n'
