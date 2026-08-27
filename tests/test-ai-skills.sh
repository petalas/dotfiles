#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-ai-skills.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
log="$fixture/npx.log"
export AI_SKILLS_TEST_LOG="$log"
export PATH="$fixture/bin:/usr/bin:/bin"
expected_agents=(
    aider-desk amp antigravity antigravity-cli astrbot autohand-code augment bob
    claude-code openclaw cline codearts-agent codebuddy codemaker codestudio codex
    command-code continue cortex crush cursor deepagents devin dexto droid firebender
    forgecode gemini-cli github-copilot goose grok hermes-agent inference-sh jazz junie
    iflow-cli kilo kimchi kimi-code-cli kiro-cli kode lingma loaf mcpjam minimax-code
    mistral-vibe moxby mux opencode openhands ona pi posit-assistant qoder qoder-cn
    qwen-code replit reasonix rovodev roo tabnine-cli terramind tinycloud trae trae-cn
    warp windsurf zed zcode zencoder zenflow neovate pochi adal universal
)
expected_agent_fields=$'\t--agent'
for expected_agent in "${expected_agents[@]}"; do
    expected_agent_fields+=$'\t'"$expected_agent"
done
expected_agent_fields+=$'\t--yes'

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
# Exercise install-plan with nounset enabled when a newer Bash is available.
if [[ -x /opt/homebrew/bin/bash ]]; then
    ln -s /opt/homebrew/bin/bash "$fixture/bin/bash"
fi

# shellcheck source=../installers/install_ai_skills.sh disable=SC1091
source "$repo_dir/installers/install_ai_skills.sh"

install_ai_skills
if grep -Fq $'\t--agent\t*\t' "$log" || grep -Eq $'\t(eve|promptscript)(\t|$)' "$log"; then
    echo 'Global skill installation included project-only agent targets' >&2
    exit 1
fi
cat >"$fixture/expected.log" <<EOF
--yes	skills	add	https://github.com/agentspace-so/agent-skills.git	--skill	gpt-image-2	--global${expected_agent_fields}
--yes	skills	add	https://github.com/petalas/skills.git	--skill	commit-guidelines	safe-refactor	principle-boundary-discipline	principle-build-the-lever	principle-encode-lessons-in-structure	principle-exhaust-the-design-space	principle-experience-first	principle-fix-root-causes	principle-foundational-thinking	principle-guard-the-context-window	principle-laziness-protocol	principle-make-operations-idempotent	principle-replace-internal-apis-atomically	principle-minimize-reader-load	principle-model-domain-in-code	principle-local-autonomy	principle-outcome-oriented-execution	principle-prove-it-works	principle-redesign-from-first-principles	principle-separate-before-serializing-shared-state	principle-sequence-verifiable-units	principle-subtract-before-you-add	principle-type-system-discipline	unslop	bro	technical-writing	typescript-best-practices	regression-test	how	why	explain-code	recall	blast-radius	architect	arena	adversarial-review	swarm	review-code-comments	show-me-your-work	create-verification-skill	maintain-verification-skill	automate-me	reflect	auditable-run	configure-agent-models	engineering-mode	worktree-cleanup	--global${expected_agent_fields}
EOF
cmp -s "$fixture/expected.log" "$log" || {
    diff -u "$fixture/expected.log" "$log" >&2 || true
    exit 1
}

: >"$log"
if NPX_FAIL_SOURCE=https://github.com/petalas/skills.git install_ai_skills >/dev/null 2>"$fixture/failure.err"; then
    echo "Expected npx failures to propagate" >&2
    exit 1
fi
grep -Fq 'Failed to install AI skills from https://github.com/petalas/skills.git' "$fixture/failure.err"
grep -Fq $'https://github.com/petalas/skills.git\t--skill\tcommit-guidelines\tsafe-refactor\tprinciple-boundary-discipline' "$log"

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
cat >"$fixture/expected-ai-skill-install.log" <<EOF
--yes	skills	add	https://github.com/cursor/plugins.git	--skill	unslop	--global${expected_agent_fields}
EOF
cmp -s "$fixture/expected-ai-skill-install.log" "$log"

# Installation plans group selected skills by source so one repository is
# fetched once even when it provides several skills.
batch_catalog="$fixture/batch-catalog"
mkdir -p "$batch_catalog/platforms"
cp "$skill_catalog/steps.tsv" "$batch_catalog/steps.tsv"
cp "$skill_catalog/groups.tsv" "$batch_catalog/groups.tsv"
cp "$skill_catalog/applications.tsv" "$batch_catalog/applications.tsv"
cp "$skill_catalog/platforms/macos.tsv" "$batch_catalog/platforms/macos.tsv"
cat >"$batch_catalog/ai-skills.tsv" <<'EOF'
https://github.com/example/one.git	alpha
https://github.com/example/one.git	beta
https://github.com/example/two.git	gamma
EOF
DOTFILES_CATALOG_DIR="$batch_catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$fixture/batch-skills.plan" >/dev/null
: >"$log"
DOTFILES_CATALOG_DIR="$batch_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/batch-skills.plan" >/dev/null
cat >"$fixture/expected-batch-skill-install.log" <<EOF
--yes	skills	add	https://github.com/example/one.git	--skill	alpha	beta	--global${expected_agent_fields}
--yes	skills	add	https://github.com/example/two.git	--skill	gamma	--global${expected_agent_fields}
EOF
cmp -s "$fixture/expected-batch-skill-install.log" "$log" || {
    diff -u "$fixture/expected-batch-skill-install.log" "$log" >&2 || true
    exit 1
}

# A failed repository batch is reported for its skills without retrying each
# skill as another repository fetch. Independent source batches still run.
: >"$log"
if NPX_FAIL_SOURCE=https://github.com/example/one.git \
    DOTFILES_CATALOG_DIR="$batch_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/batch-skills.plan" \
    >"$fixture/batch-failure.out" 2>"$fixture/batch-failure.err"; then
    echo "Expected a failed AI skill source batch to fail the installation plan" >&2
    exit 1
fi
cmp -s "$fixture/expected-batch-skill-install.log" "$log" || {
    diff -u "$fixture/expected-batch-skill-install.log" "$log" >&2 || true
    exit 1
}
grep -Fq 'failed: ai-skills.alpha' "$fixture/batch-failure.err"
grep -Fq 'failed: ai-skills.beta' "$fixture/batch-failure.err"
grep -Fq 'succeeded: ai-skills.gamma' "$fixture/batch-failure.out"

# Reconciliation does not fetch a source when every selected skill from that
# source is already recorded in the global skill lock.
cat >"$fixture/installed-skill-lock.json" <<'EOF'
{
  "skills": {
    "alpha": { "sourceUrl": "https://github.com/example/one.git" },
    "beta": { "sourceUrl": "https://github.com/example/one.git" },
    "gamma": { "sourceUrl": "https://github.com/example/two.git" }
  }
}
EOF
: >"$log"
DOTFILES_AI_SKILLS_LOCK="$fixture/installed-skill-lock.json" \
DOTFILES_CATALOG_DIR="$batch_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation reconcile --plan "$fixture/batch-skills.plan" \
    >"$fixture/batch-reconcile.out" 2>"$fixture/batch-reconcile.err"
if [[ -s "$log" ]]; then
    echo "Expected installed AI skill sources to require no reconciliation fetch" >&2
    cat "$log" >&2
    exit 1
fi
grep -Fq 'succeeded: ai-skills.alpha' "$fixture/batch-reconcile.out"
grep -Fq 'succeeded: ai-skills.beta' "$fixture/batch-reconcile.out"
grep -Fq 'succeeded: ai-skills.gamma' "$fixture/batch-reconcile.out"

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
cat >"$fixture/expected-ai-skill-remove.log" <<EOF
--yes	skills	remove	--global	--skill	unslop${expected_agent_fields}
EOF
cmp -s "$fixture/expected-ai-skill-remove.log" "$log"

printf 'AI skills installer tests passed.\n'
