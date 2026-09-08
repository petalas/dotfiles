#!/usr/bin/env bash
set -euo pipefail

command -v zsh >/dev/null 2>&1 || {
    echo "Zsh is unavailable; skipping startup test."
    exit 0
}
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-zsh-startup.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/.sdkman/bin" "$fixture/.sdkman/candidates/java/current/bin" \
    "$fixture/.sdkman/candidates/gradle/current/bin"
for command_name in java gradle; do
    printf '#!/usr/bin/env sh\nexit 0\n' >"$fixture/.sdkman/candidates/$command_name/current/bin/$command_name"
    chmod +x "$fixture/.sdkman/candidates/$command_name/current/bin/$command_name"
done
cat >"$fixture/.sdkman/bin/sdkman-init.sh" <<'EOF'
for candidate_name in java gradle; do
    candidate_dir="$SDKMAN_DIR/candidates/$candidate_name/current/bin"
    case ":$PATH:" in *":$candidate_dir:"*) ;; *) PATH="$candidate_dir:$PATH" ;; esac
done
export PATH
EOF

inherited_path="/usr/bin:/bin:$fixture/.sdkman/candidates/java/current/bin:$fixture/.sdkman/candidates/gradle/current/bin"
HOME="$fixture" PATH="$inherited_path" zsh -dfc '
    source "$1"
    java_dir="$HOME/.sdkman/candidates/java/current/bin"
    gradle_dir="$HOME/.sdkman/candidates/gradle/current/bin"
    (( ${path[(Ie)$java_dir]} < ${path[(Ie)/usr/bin]} ))
    (( ${path[(Ie)$gradle_dir]} < ${path[(Ie)/usr/bin]} ))
    [[ $commands[java] == "$java_dir/java" ]]
    [[ $commands[gradle] == "$gradle_dir/gradle" ]]
    (( $+functions[upd] ))
    (( $+functions[y] ))
    (( $+functions[kill-port] ))
' zsh "$repo_dir/dot/zshrc" 2>"$fixture/stderr"
if grep -Eqi 'no such file|command not found' "$fixture/stderr"; then
    cat "$fixture/stderr" >&2
    exit 1
fi
# Current pnpm separates its launcher from global executables. Respect an existing
# PNPM_HOME, including paths containing spaces, and keep both executable roots.
pnpm_test_home="$fixture/custom pnpm"
mkdir -p "$pnpm_test_home/bin"
printf '#!/usr/bin/env sh\nexit 0\n' >"$pnpm_test_home/pnpm"
printf '#!/usr/bin/env sh\nexit 0\n' >"$pnpm_test_home/bin/pnpm-global-example"
chmod +x "$pnpm_test_home/pnpm" "$pnpm_test_home/bin/pnpm-global-example"
HOME="$fixture" PNPM_HOME="$pnpm_test_home" PATH="$inherited_path" zsh -dfc '
    source "$1"
    [[ $commands[pnpm] == "$PNPM_HOME/pnpm" ]] || exit 1
    [[ $commands[pnpm-global-example] == "$PNPM_HOME/bin/pnpm-global-example" ]] || exit 1
' zsh "$repo_dir/dot/zshrc" 2>"$fixture/pnpm-stderr"
# A clean shell also configures the platform default without pnpm setup editing
# the managed zshrc, even before that directory has been created.
env -u PNPM_HOME HOME="$fixture" XDG_DATA_HOME="$fixture/data" PATH="$inherited_path" zsh -dfc '
    source "$1"
    if [[ $OSTYPE == darwin* ]]; then
        [[ $PNPM_HOME == "$HOME/Library/pnpm" ]] || exit 1
    else
        [[ $PNPM_HOME == "$XDG_DATA_HOME/pnpm" ]] || exit 1
    fi
    (( ${path[(Ie)$PNPM_HOME]} )) || exit 1
    pnpm_bin="$PNPM_HOME/bin"
    (( ${path[(Ie)$pnpm_bin]} )) || exit 1
' zsh "$repo_dir/dot/zshrc" 2>"$fixture/pnpm-default-stderr"
printf 'Zsh startup guards passed.\n'
