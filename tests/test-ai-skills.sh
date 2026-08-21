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

skill_catalog="$fixture/catalog"
mkdir -p "$skill_catalog/platforms"
cat >"$skill_catalog/steps.tsv" <<'EOF'
10	dependencies	Install dependencies	on	dependencies
EOF
cat >"$skill_catalog/groups.tsv" <<'EOF'
10	languages	Languages	on
20	ai-skills	AI skills	on
EOF
cat >"$skill_catalog/applications.tsv" <<'EOF'
languages.node	languages	Node	required
EOF
cat >"$skill_catalog/platforms/macos.tsv" <<'EOF'
languages.node	provided	payload	provided	node
EOF
cat >"$skill_catalog/ai-skills.tsv" <<'EOF'
https://github.com/cursor/plugins.git	unslop
EOF

DOTFILES_CATALOG_DIR="$skill_catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$fixture/skill.plan" >/dev/null
grep -Fxq $'group\tai-skills\ton\t20\tAI skills\tavailable' "$fixture/skill.plan"
grep -Fxq $'app\tai-skills.unslop\ton\toptional\tai-skills\tAI skill: unslop' "$fixture/skill.plan"
grep -Fxq $'dependency\tai-skills.unslop\tlanguages.node' "$fixture/skill.plan"
grep -Fxq $'action\tai-skills.unslop\tai-skill\thttps://github.com/cursor/plugins.git\tunslop' "$fixture/skill.plan"

: >"$log"
DOTFILES_CATALOG_DIR="$skill_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/skill.plan" >/dev/null
cat >"$fixture/expected-ai-skill-install.log" <<'EOF'
--yes	skills	add	https://github.com/cursor/plugins.git	--skill	unslop	--global	--agent	*	--yes
EOF
cmp -s "$fixture/expected-ai-skill-install.log" "$log"

cat >"$fixture/observations.tsv" <<'EOF'
format	1
os	macos
observation	languages.node	available	present	provided	required	disabled	disabled	languages	Node	node is present
observation	ai-skills.unslop	available	present	managed	optional	enabled	disabled	ai-skills	AI skill: unslop	unslop is installed
mechanism	ai-skills.unslop	ai-skill	https://github.com/cursor/plugins.git	unslop
EOF
cat >"$fixture/selection.tsv" <<'EOF'
format	1
outcome	ai-skills.unslop	remove
EOF
DOTFILES_CATALOG_DIR="$skill_catalog" "$repo_dir/lib/install-plan" prepare --mode outcomes --os macos \
    --selection "$fixture/selection.tsv" --observations "$fixture/observations.tsv" \
    --output "$fixture/remove.plan" >/dev/null
grep -Fxq $'app\tai-skills.unslop\tremove\toptional\tai-skills\tAI skill: unslop\tpresent\tmanaged' \
    "$fixture/remove.plan"
grep -Fxq $'removal\tai-skills.unslop\texact\tai-skill\thttps://github.com/cursor/plugins.git\tunslop' \
    "$fixture/remove.plan"
: >"$log"
DOTFILES_CATALOG_DIR="$skill_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/remove.plan" >/dev/null
cat >"$fixture/expected-ai-skill-remove.log" <<'EOF'
--yes	skills	remove	--global	--skill	unslop	--agent	*	--yes
EOF
cmp -s "$fixture/expected-ai-skill-remove.log" "$log"

printf 'AI skills installer tests passed.\n'
