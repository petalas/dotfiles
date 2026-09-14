#!/usr/bin/env bash
# Inspect the real machine through the visual installer and check that the
# complete catalog settles. Read-only: it runs `inspect`, never `execute`.
#
# Usage: tests/live/test-macos-inspection.sh [TUI_BINARY]
#   Without an argument, tools/run-install-tui provides the verified release
#   binary, so a developer Mac can run this without a Go toolchain.
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_dir"
tui=${1:-$repo_dir/tools/run-install-tui}
[[ -x "$tui" ]] || { echo "TUI launcher is not executable: $tui" >&2; exit 2; }

fixture=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-live-inspection.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

fail() {
    echo "FAIL: $*" >&2
    echo "--- inspection progress (tail) ---" >&2
    tail -n 40 "$fixture/progress" >&2 || true
    exit 1
}

# Every catalog application must appear exactly once in the observation
# snapshot. Applications are catalog/applications.tsv rows; AI skills join the
# plan as `ai-skills.<skill>` from catalog/ai-skills.tsv.
{
    awk -F '\t' 'NF >= 4 && $1 !~ /^#/ { print $1 }' catalog/applications.tsv
    awk -F '\t' 'NF == 2 && $1 !~ /^#/ { print "ai-skills." $2 }' catalog/ai-skills.tsv
} | sort >"$fixture/expected-ids"
expected=$(wc -l <"$fixture/expected-ids" | tr -d ' ')
((expected > 0)) || { echo "catalog produced no application ids" >&2; exit 2; }

if ! TERM=xterm "$tui" run -- ./lib/install-plan inspect --os macos --output "$fixture/observations" >"$fixture/progress" 2>&1; then
    fail "visual inspection exited with status $?"
fi
grep -Fq "$expected/$expected settled" "$fixture/progress" || fail "progress never reported $expected/$expected settled"
grep -Fq 'Run settled successfully.' "$fixture/progress" || fail "run did not settle successfully"

grep '^observation'$'\t' "$fixture/observations" | cut -f2 | sort >"$fixture/observed-ids"
if ! diff -u "$fixture/expected-ids" "$fixture/observed-ids" >"$fixture/id-diff"; then
    cat "$fixture/id-diff" >&2
    fail "observation snapshot does not match the catalog (expected $expected applications)"
fi
printf 'Live macOS inspection settled %s catalog applications.\n' "$expected"
