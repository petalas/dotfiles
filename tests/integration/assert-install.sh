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

assert_mode() {
    local path="$1"
    local expected="$2"
    local actual
    actual=$(stat -c '%a' "$path")
    [[ "$actual" == "$expected" ]] || fail "$path mode is $actual, expected $expected"
}

assert_git_checkout() {
    local path="$1"
    local expected_origin="$2"
    local expected_branch="${3:-}"
    local allow_untracked="${4:-false}"
    local actual_origin actual_branch checkout_status

    [[ -d "$path/.git" ]] || fail "Git checkout is missing: $path"
    actual_origin=$(git -C "$path" remote get-url origin)
    # TPM's clone helper may store GitHub HTTPS URLs with a no-op `git::@`
    # userinfo segment; normalize it before comparing repository identity.
    actual_origin=${actual_origin/https:\/\/git::@github.com\//https:\/\/github.com\/}
    [[ "${actual_origin%.git}" == "${expected_origin%.git}" ]] ||
        fail "$path origin is $actual_origin, expected $expected_origin"
    if [[ "$allow_untracked" == true ]]; then
        checkout_status=$(git -C "$path" status --porcelain --untracked-files=no)
    else
        checkout_status=$(git -C "$path" status --porcelain)
    fi
    [[ -z "$checkout_status" ]] ||
        fail "Git checkout is dirty: $path: $checkout_status"
    if [[ -n "$expected_branch" ]]; then
        actual_branch=$(git -C "$path" branch --show-current)
        [[ "$actual_branch" == "$expected_branch" ]] ||
            fail "$path branch is $actual_branch, expected $expected_branch"
    fi
}

LC_ALL=en_US.UTF-8 locale charmap | grep -qx UTF-8 ||
    fail "en_US.UTF-8 is not generated"

for command_name in diff git jq locale mosh mosh-server tmux zsh; do
    assert_command "$command_name"
done

assert_link "$HOME/.zshrc" "$repo_dir/dot/zshrc"
assert_link "$HOME/.seashells.zsh" "$repo_dir/dot/seashells.zsh"
assert_link "$HOME/.p10k-seashells.zsh" "$repo_dir/dot/p10k-seashells.zsh"

shell_theme_check=$(zsh -fc 'source ~/.seashells.zsh; printf "%s|%s" "$LS_COLORS" "$EZA_COLORS"')
[[ "$shell_theme_check" == *"di=01;94"*"|"*"hd=1;93"* ]] ||
    fail "SeaShells LS_COLORS/EZA_COLORS were not loaded"
p10k_theme_check=$(zsh -fc '
    typeset -g POWERLEVEL9K_TEST_FOREGROUND=255
    typeset -g POWERLEVEL9K_TEST_BACKGROUND=208
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="%244F---"
    source ~/.p10k-seashells.zsh
    printf "%s|%s|%s" "$POWERLEVEL9K_TEST_FOREGROUND" "$POWERLEVEL9K_TEST_BACKGROUND" "$POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX"
')
[[ "$p10k_theme_check" == "15|3|%8F---" ]] ||
    fail "Powerlevel10k colors were not normalized: $p10k_theme_check"

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
assert_mode "$HOME/.ssh" 700
assert_mode "$HOME/.ssh/config" 600
assert_link "$HOME/.claude/CLAUDE.md" "$repo_dir/dot/claude/CLAUDE.md"
if [[ -e "$repo_dir/dot/claude/settings.json" ]]; then
    assert_link "$HOME/.claude/settings.json" "$repo_dir/dot/claude/settings.json"
fi
for command_file in "$repo_dir"/dot/claude/commands/*.md; do
    assert_link "$HOME/.claude/commands/$(basename "$command_file")" "$command_file"
done

grep -Fqx 'Include ~/.ssh/config.shared' "$HOME/.ssh/config" ||
    fail "SSH config does not include the shared config"

# Powerlevel10k is an intentional nested checkout under the Oh My Zsh tree,
# so require its tracked files to be clean while checking that child separately.
assert_git_checkout "$HOME/.oh-my-zsh" https://github.com/ohmyzsh/ohmyzsh.git master true
assert_git_checkout "$HOME/.oh-my-zsh/themes/powerlevel10k" https://github.com/romkatv/powerlevel10k.git master
assert_git_checkout "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" https://github.com/zsh-users/zsh-autosuggestions master
assert_git_checkout "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" https://github.com/zsh-users/zsh-syntax-highlighting.git master
assert_git_checkout "$HOME/.oh-my-zsh/custom/plugins/fast-syntax-highlighting" https://github.com/zdharma-continuum/fast-syntax-highlighting.git master
assert_git_checkout "$HOME/.oh-my-zsh/custom/plugins/autoupdate" https://github.com/TamCore/autoupdate-oh-my-zsh-plugins master
assert_git_checkout "$HOME/.config/nvim" https://github.com/petalas/nvim.git custom
assert_git_checkout "$HOME/.tmux/plugins/tpm" https://github.com/tmux-plugins/tpm.git master
assert_git_checkout "$HOME/.tmux/plugins/tmux-better-mouse-mode" https://github.com/NHDaly/tmux-better-mouse-mode master

[[ "$(git -C "$repo_dir" config --local core.hooksPath)" == ".githooks" ]] ||
    fail "repository hooks path is not configured"
sudo visudo -cf /etc/sudoers.d/dotfiles >/dev/null || fail "sudoers entry is invalid"

zsh_locale=$(env -u LANG -u LC_ALL -u LC_CTYPE zsh -ic 'printf "%s|%s|%s" "$LANG" "${LC_ALL-unset}" "${LC_CTYPE-unset}"')
[[ "$zsh_locale" == *"en_US.UTF-8|unset|unset" ]] ||
    fail "zsh did not select the generated UTF-8 locale: $zsh_locale"

tmux_socket="dotfiles-integration-$$"
cleanup() {
    tmux -L "$tmux_socket" kill-server 2>/dev/null || true
}
trap cleanup EXIT

if [[ "${EXPECT_STALE_TMUX_RELOAD:-0}" == 1 ]]; then
    tmux_plugin_env=$(tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>/dev/null || true)
    [[ "$tmux_plugin_env" == TMUX_PLUGIN_MANAGER_PATH=* ]] ||
        fail "the stale tmux server did not reload TMUX_PLUGIN_MANAGER_PATH"
fi

tmux -L "$tmux_socket" -f "$HOME/.tmux.conf" new-session -d
[[ "$(tmux -L "$tmux_socket" show-options -gqv mouse)" == "on" ]] ||
    fail "tmux mouse mode is not enabled"

mosh-server --version 2>&1 | grep -qi mosh || fail "mosh-server version check failed"
set +e
mosh_output=$(env LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 timeout 3 \
    mosh-server new -c 256 2>&1)
mosh_status=$?
set -e
[[ "$mosh_status" == 0 || "$mosh_status" == 124 ]] ||
    fail "mosh-server launch failed ($mosh_status): $mosh_output"
[[ "$mosh_output" == *"MOSH CONNECT"* ]] ||
    fail "mosh-server did not bind a UTF-8 session: $mosh_output"
if grep -qiE 'locale.*(missing|invalid|unavailable)|requires.*UTF-8' <<<"$mosh_output"; then
    fail "mosh-server rejected the configured locale: $mosh_output"
fi

if find -L "$HOME" -type l -print -quit | grep -q .; then
    fail "the install left a broken symlink under $HOME"
fi

echo "Integration assertions passed for $(. /etc/os-release && printf '%s' "$PRETTY_NAME")"
