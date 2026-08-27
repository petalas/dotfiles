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
printf 'Zsh startup guards passed.\n'
