#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-update-plan.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/.git" "$fixture/repo/lib" "$fixture/bin" "$fixture/home"
cp "$repo_dir/update-dotfiles" "$fixture/repo/update-dotfiles"
cat >"$fixture/repo/lib/install-plan" <<'EOF'
#!/usr/bin/env bash
printf 'plan %s\n' "$*" >>"$UPDATE_TEST_LOG"
if [[ "$1" == prepare ]]; then
    while (($#)); do
        if [[ "$1" == --output ]]; then printf 'plan\n' >"$2"; break; fi
        shift
    done
fi
EOF
cat >"$fixture/repo/lib/packages.sh" <<'EOF'
linux_packages_upgrade() { printf 'system upgrade\n' >>"$UPDATE_TEST_LOG"; }
EOF
cat >"$fixture/repo/lib/platform.sh" <<'EOF'
dotfiles_os() { echo debian; }
EOF
cat >"$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *'status --porcelain') : ;;
    *'pull --ff-only') : ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$fixture/repo/update-dotfiles" "$fixture/repo/lib/install-plan" "$fixture/bin/git"

log="$fixture/update.log"
UPDATE_TEST_LOG="$log" DOTFILES_DIR="$fixture/repo" HOME="$fixture/home" \
    PATH="$fixture/bin:/bin" /usr/bin/zsh "$fixture/repo/update-dotfiles" \
    >"$fixture/out" 2>"$fixture/err"
grep -Fq 'plan prepare --mode defaults' "$log"
grep -Fq 'plan apply --operation reconcile' "$log"
grep -Fxq 'system upgrade' "$log"
[[ "$(grep -c '^plan apply ' "$log")" == 1 ]]

printf 'Update plan integration tests passed.\n'
