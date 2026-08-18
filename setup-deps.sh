#!/usr/bin/env bash
# Compatibility wrapper: install only the dependency step through the catalog.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$root_dir"
# shellcheck source=lib/platform.sh
source lib/platform.sh
os=$(dotfiles_os) || { echo "Unsupported OS: $(uname -s)" >&2; exit 1; }
require_noninteractive_root
engine=${DOTFILES_INSTALL_PLAN_ENGINE:-$root_dir/lib/install-plan}
record=$(mktemp "${TMPDIR:-/tmp}/dotfiles-dependencies-record.XXXXXX")
plan=$(mktemp "${TMPDIR:-/tmp}/dotfiles-dependencies-plan.XXXXXX")
trap 'rm -f "$record" "$plan"' EXIT

{
    echo 'format=1'
    while IFS=$'\t' read -r _ id _rest; do
        [[ -n "$id" ]] || continue
        if [[ "$id" == dependencies ]]; then value=on; else value=off; fi
        printf 'step.%s=%s\n' "$id" "$value"
    done <catalog/steps.tsv
    while IFS=$'\t' read -r _ id _rest; do
        [[ -n "$id" ]] && printf 'group.%s=on\n' "$id"
    done <catalog/groups.tsv
} >"$record"

"$engine" prepare --mode record --record "$record" --os "$os" --output "$plan"
export NONINTERACTIVE=1 HOMEBREW_NO_ASK=1 DOTFILES_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a GIT_TERMINAL_PROMPT=0
exec </dev/null
"$engine" apply --operation install --plan "$plan"
