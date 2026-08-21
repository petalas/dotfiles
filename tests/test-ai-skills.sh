#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-ai-skills.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
log="$fixture/npx.log"
export AI_SKILLS_TEST_LOG="$log"
export PATH="$fixture/bin:/usr/bin:/bin"

cat >"$fixture/bin/npx" <<'EOF'
#!/usr/bin/env bash
first=1
for argument in "$@"; do
    if ((first)); then
        printf '%s' "$argument"
        first=0
    else
        printf '\t%s' "$argument"
    fi
done >>"$AI_SKILLS_TEST_LOG"
printf '\n' >>"$AI_SKILLS_TEST_LOG"
if [[ -n "${NPX_FAIL_SOURCE:-}" && " $* " == *" $NPX_FAIL_SOURCE "* ]]; then
    exit 1
fi
EOF
chmod +x "$fixture/bin/npx"

# shellcheck source=../installers/install_ai_skills.sh disable=SC1091
source "$repo_dir/installers/install_ai_skills.sh"

install_ai_skills
cat >"$fixture/expected.log" <<'EOF'
--yes	skills	add	https://github.com/agentspace-so/agent-skills.git	--skill	gpt-image-2	--global	--agent	*	--yes
--yes	skills	add	https://github.com/cursor/plugins.git	--skill	unslop	--global	--agent	*	--yes
--yes	skills	add	https://github.com/mattpocock/skills.git	--skill	ask-matt	code-review	codebase-design	diagnosing-bugs	domain-modeling	grill-me	grill-with-docs	grilling	handoff	implement	improve-codebase-architecture	prototype	research	resolving-merge-conflicts	setup-matt-pocock-skills	tdd	teach	to-spec	to-tickets	triage	wayfinder	wizard	--global	--agent	*	--yes
--yes	skills	add	https://github.com/petalas/skills.git	--skill	fix-all-issues	safe-refactor	--global	--agent	*	--yes
EOF
cmp -s "$fixture/expected.log" "$log" || {
    diff -u "$fixture/expected.log" "$log" >&2 || true
    exit 1
}

: >"$log"
if NPX_FAIL_SOURCE=https://github.com/cursor/plugins.git install_ai_skills >/dev/null 2>"$fixture/failure.err"; then
    echo "Expected npx failures to propagate" >&2
    exit 1
fi
grep -Fq 'Failed to install AI skills from https://github.com/cursor/plugins.git' "$fixture/failure.err"
grep -Fq $'https://github.com/petalas/skills.git\t--skill\tfix-all-issues\tsafe-refactor' "$log"

cat >"$fixture/duplicate.tsv" <<'EOF'
https://github.com/example/one.git	duplicated
https://github.com/example/two.git	duplicated
EOF
if DOTFILES_AI_SKILLS_CATALOG="$fixture/duplicate.tsv" install_ai_skills >/dev/null 2>"$fixture/duplicate.err"; then
    echo "Expected duplicate skills to be rejected" >&2
    exit 1
fi
grep -Fq 'Duplicate AI skill in catalog: duplicated' "$fixture/duplicate.err"

printf 'AI skills installer tests passed.\n'
