#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-setup-tools.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home" "$fixture/unauthenticated-home" \
    "$fixture/invalid-home/git/notes"
touch "$fixture/home/.tmux.conf" "$fixture/unauthenticated-home/.tmux.conf"

cat >"$fixture/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == auth && "${2:-}" == status ]]; then
    exit "${GH_AUTH_EXIT:-0}"
fi
exit 2
EOF

cat >"$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'config_count=%s helper=%s args=' \
    "${GIT_CONFIG_COUNT:-}" "${GIT_CONFIG_VALUE_1:-}" >>"$GIT_LOG"
printf '%s ' "$@" >>"$GIT_LOG"
printf '\n' >>"$GIT_LOG"

if [[ "${1:-}" == clone ]]; then
    arguments=("$@")
    last=$((${#arguments[@]} - 1))
    destination=${arguments[$last]}
    repository=${arguments[$((last - 1))]}
    branch=main
    for ((index = 1; index < last; index++)); do
        if [[ "${arguments[$index]}" == --branch ]]; then
            branch=${arguments[$((index + 1))]}
        fi
    done
    mkdir -p "$destination/.git"
    printf '%s\n' "$repository" >"$destination/.git/fixture-origin"
    printf '%s\n' "$branch" >"$destination/.git/fixture-branch"
    if [[ "$repository" == https://github.com/tmux-plugins/tpm.git ]]; then
        mkdir -p "$destination/bin"
        printf '#!/usr/bin/env bash\nexit 0\n' >"$destination/bin/install_plugins"
        chmod +x "$destination/bin/install_plugins"
    fi
    exit 0
fi

if [[ "${1:-}" == -C ]]; then
    checkout=$2
    shift 2
    case "$1 ${2:-} ${3:-}" in
        'status --porcelain ') exit 0 ;;
        'remote get-url origin') cat "$checkout/.git/fixture-origin"; exit 0 ;;
        'branch --show-current ') cat "$checkout/.git/fixture-branch"; exit 0 ;;
        'pull --ff-only --quiet') exit 0 ;;
    esac
fi

printf 'Unexpected fake git invocation: %s\n' "$*" >&2
exit 2
EOF

cat >"$fixture/bin/tmux" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$fixture/bin/bat" <<'EOF'
#!/usr/bin/env bash
printf "No syntaxes were found in '%s/.config/bat/syntaxes', using the default set.\n" "$HOME"
printf 'Writing theme set ... okay\n'
EOF
chmod +x "$fixture/bin/gh" "$fixture/bin/git" "$fixture/bin/tmux" "$fixture/bin/bat"

export GIT_LOG="$fixture/git.log"
test_path="$fixture/bin:/usr/bin:/bin"
HOME="$fixture/home" PATH="$test_path" GH_AUTH_EXIT=0 "$repo_dir/setup-tools.sh" \
    >"$fixture/setup.out" 2>"$fixture/setup.err"
if grep -Fq 'No syntaxes were found' "$fixture/setup.out" "$fixture/setup.err"; then
    echo 'Expected bat default-syntax notice to be omitted' >&2
    exit 1
fi
grep -Fq 'Writing theme set ... okay' "$fixture/setup.out"
[[ -d "$fixture/home/git/notes/.git" ]]
[[ -L "$fixture/home/git/notes/.obsidian/app.json" ]]
jq -e '.alwaysUpdateLinks == true' \
    "$fixture/home/git/notes/.obsidian/app.json" >/dev/null
grep -Fq "args=clone --branch main https://github.com/petalas/notes.git $fixture/home/git/notes " \
    "$GIT_LOG"
grep -Fq 'config_count=2 helper=!gh auth git-credential args=clone --branch main https://github.com/petalas/notes.git' \
    "$GIT_LOG"

printf 'draft\n' >"$fixture/home/git/notes/uncommitted.md"
HOME="$fixture/home" PATH="$test_path" GH_AUTH_EXIT=1 "$repo_dir/setup-tools.sh" >/dev/null
[[ "$(grep -Fc "https://github.com/petalas/notes.git $fixture/home/git/notes " "$GIT_LOG")" == 1 ]]
grep -Fxq 'draft' "$fixture/home/git/notes/uncommitted.md"
if grep -Fq "args=-C $fixture/home/git/notes pull " "$GIT_LOG"; then
    echo 'Existing notes checkout was unexpectedly pulled.' >&2
    exit 1
fi

HOME="$fixture/unauthenticated-home" PATH="$test_path" GH_AUTH_EXIT=1 \
    "$repo_dir/setup-tools.sh" >"$fixture/unauthenticated.out" 2>"$fixture/unauthenticated.err"
[[ ! -e "$fixture/unauthenticated-home/git/notes" ]]
grep -Fq "gh auth login --hostname github.com --git-protocol https --web" \
    "$fixture/unauthenticated.err"

if HOME="$fixture/invalid-home" PATH="$test_path" GH_AUTH_EXIT=0 \
    "$repo_dir/setup-tools.sh" >"$fixture/invalid.out" 2>"$fixture/invalid.err"; then
    echo 'Invalid notes path unexpectedly succeeded.' >&2
    exit 1
fi
[[ ! -e "$fixture/invalid-home/git/notes/.obsidian" ]]
grep -Fq "Cannot clone notes repository over existing path" "$fixture/invalid.err"

printf 'Generated tool and notes repository tests passed.\n'
