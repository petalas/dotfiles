#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
    echo "integration assertion failed: $*" >&2
    exit 1
}

assert_command() {
    command -v "$1" >/dev/null 2>&1 || fail "command is missing: $1"
}

assert_link() {
    local target="$1"
    local expected="$2"

    [[ -L "$target" ]] || fail "not a symlink: $target"
    [[ "$(readlink "$target")" == "$expected" ]] ||
        fail "$target points to $(readlink "$target"), expected $expected"
}

LC_ALL=en_US.UTF-8 locale charmap | grep -qx UTF-8 ||
    fail "en_US.UTF-8 is not generated"

for command_name in git jq locale mosh mosh-server tmux zsh; do
    assert_command "$command_name"
done

assert_link "$HOME/.zshrc" "$repo_dir/dot/zshrc"
assert_link "$HOME/.hushlogin" "$repo_dir/dot/hushlogin"
assert_link "$HOME/.gitconfig" "$repo_dir/dot/gitconfig"
assert_link "$HOME/.tmux.conf" "$repo_dir/dot/tmux.conf"
assert_link "$HOME/.config/ghostty/config.ghostty" "$repo_dir/dot/.config/ghostty/config.ghostty"
assert_link "$HOME/.pi/agent/extensions/openai-fast-mode.ts" "$repo_dir/dot/.pi/agent/extensions/openai-fast-mode.ts"
assert_link "$HOME/.pi/agent/themes/seashells.json" "$repo_dir/dot/.pi/agent/themes/seashells.json"
[[ "$(jq -r '.theme' "$HOME/.pi/agent/settings.json")" == "seashells" ]] ||
    fail "Pi does not select the managed seashells theme"
assert_link "$HOME/.config/yazi" "$repo_dir/dot/.config/yazi"
assert_link "$HOME/.config/bat" "$repo_dir/dot/.config/bat"
assert_link "$HOME/.ssh/config.shared" "$repo_dir/dot/.ssh/config.shared"
assert_link "$HOME/.claude/CLAUDE.md" "$repo_dir/dot/claude/CLAUDE.md"
if [[ -e "$repo_dir/dot/claude/settings.json" ]]; then
    assert_link "$HOME/.claude/settings.json" "$repo_dir/dot/claude/settings.json"
fi

grep -Fqx 'Include ~/.ssh/config.shared' "$HOME/.ssh/config" ||
    fail "SSH config does not include the shared config"

[[ -d "$HOME/.oh-my-zsh/.git" ]] || fail "Oh My Zsh was not installed"
[[ -d "$HOME/.config/nvim/.git" ]] || fail "Neovim config was not cloned"
[[ -d "$HOME/.tmux/plugins/tpm/.git" ]] || fail "TPM was not installed"
[[ -d "$HOME/.tmux/plugins/tmux-better-mouse-mode/.git" ]] ||
    fail "tmux-better-mouse-mode was not installed"

zsh_locale=$(env -u LANG -u LC_ALL -u LC_CTYPE zsh -ic 'printf "%s|%s|%s" "$LANG" "${LC_ALL-unset}" "${LC_CTYPE-unset}"')
[[ "$zsh_locale" == *"en_US.UTF-8|unset|unset" ]] ||
    fail "zsh did not select the generated UTF-8 locale: $zsh_locale"

tmux_socket="dotfiles-integration-$$"
cleanup() {
    tmux -L "$tmux_socket" kill-server 2>/dev/null || true
}
trap cleanup EXIT

tmux -L "$tmux_socket" -f "$HOME/.tmux.conf" new-session -d
[[ "$(tmux -L "$tmux_socket" show-options -gqv mouse)" == "on" ]] ||
    fail "tmux mouse mode is not enabled"

mosh-server --version 2>&1 | grep -qi mosh || fail "mosh-server cannot start"

if find -L "$HOME" -type l -print -quit | grep -q .; then
    fail "the install left a broken symlink under $HOME"
fi

echo "Integration assertions passed for $(. /etc/os-release && printf '%s' "$PRETTY_NAME")"
