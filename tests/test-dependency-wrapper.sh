#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-dependency-wrapper.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
log="$fixture/log"
mkdir -p "$fixture/bin"
cat >"$fixture/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/bin/sudo"
cat >"$fixture/engine" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DEPENDENCY_TEST_LOG"
if [[ "$1" == prepare ]]; then
    while (($#)); do
        if [[ "$1" == --output ]]; then printf 'resolved\n' >"$2"; break; fi
        shift
    done
fi
EOF
chmod +x "$fixture/engine"
DOTFILES_OS_OVERRIDE=debian DOTFILES_INSTALL_PLAN_ENGINE="$fixture/engine" \
DEPENDENCY_TEST_LOG="$log" PATH="$fixture/bin:/usr/bin:/bin" "$repo_dir/setup-deps.sh"
grep -Fq 'prepare --mode record' "$log"
grep -Fq -- '--os debian' "$log"
grep -Fq 'apply --operation install' "$log"

printf 'Dependency wrapper tests passed.\n'
