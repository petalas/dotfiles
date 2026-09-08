#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-ai-skills.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"
log="$fixture/npx.log"
node_bin=$(command -v node)
ln -s "$node_bin" "$fixture/bin/node"
export AI_SKILLS_TEST_LOG="$log"
export PATH="$fixture/bin:/usr/bin:/bin"
# Every agent skill root lives under HOME, so an isolated HOME exercises the
# real store, links, and lock paths without touching the machine.
export HOME="$fixture/home"
expected_agents=(claude-code codex pi universal)
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

# Create a skill in the canonical store with the links the skills CLI creates.
store="$HOME/.agents/skills"
install_fake_skill() {
    local skill=$1
    mkdir -p "$store/$skill" "$HOME/.claude/skills" "$HOME/.codex/skills" \
        "$HOME/.pi/agent/skills"
    : >"$store/$skill/SKILL.md"
    ln -sfn "../../.agents/skills/$skill" "$HOME/.claude/skills/$skill"
    ln -sfn "../../.agents/skills/$skill" "$HOME/.codex/skills/$skill"
    ln -sfn "../../../.agents/skills/$skill" "$HOME/.pi/agent/skills/$skill"
}

# The catalog is kept sorted by source, then skill, so rows have one place.
LC_ALL=C sort -c -t $'\t' -k1,1 -k2,2 "$repo_dir/catalog/ai-skills.tsv" || {
    echo 'catalog/ai-skills.tsv must be sorted by source then skill' >&2
    exit 1
}

# Source validation accepts git URLs and owner/repo shorthand, optionally
# pinned with #ref, and rejects relative paths and malformed pins.
for valid in https://github.com/example/one.git git@github.com:example/one.git example/one \
    example/one#v1.2.0 'https://github.com/example/one.git#0123456789abcdef0123456789abcdef01234567' \
    example/one#release/2026; do
    ai_skill_valid_source "$valid" || { echo "Rejected valid source: $valid" >&2; exit 1; }
done
for invalid in '' -flag './example/one' 'example/../one' '.hidden/one' 'example/one#' \
    'example/one#a#b' 'example/one#-ref' 'example one' 'example'; do
    if ai_skill_valid_source "$invalid"; then
        echo "Accepted invalid source: $invalid" >&2
        exit 1
    fi
done
[[ "$(ai_skill_source_repo 'https://github.com/example/one.git#v1')" == https://github.com/example/one ]]
[[ "$(ai_skill_source_ref 'https://github.com/example/one.git#v1')" == v1 ]]
[[ -z "$(ai_skill_source_ref https://github.com/example/one.git)" ]]

install_ai_skills
if grep -Fq $'\t--agent\t*\t' "$log" || grep -Eq $'\t(eve|promptscript)(\t|$)' "$log"; then
    echo 'Global skill installation included project-only agent targets' >&2
    exit 1
fi
cat >"$fixture/expected.log" <<EOF
--yes	skills	add	https://github.com/agentspace-so/agent-skills.git	--skill	gpt-image-2	--global${expected_agent_fields}
--yes	skills	add	https://github.com/petalas/skills.git	--skill	adversarial-review	architect	arena	auditable-run	automate-me	blast-radius	bro	commit-guidelines	configure-agent-models	create-verification-skill	engineering-mode	explain-code	how	maintain-verification-skill	power-of-ten	principle-attack-the-premise	principle-boundary-discipline	principle-build-the-lever	principle-encode-lessons-in-structure	principle-exhaust-the-design-space	principle-experience-first	principle-fix-root-causes	principle-foundational-thinking	principle-guard-the-context-window	principle-laziness-protocol	principle-local-autonomy	principle-make-operations-idempotent	principle-minimize-reader-load	principle-model-domain-in-code	principle-outcome-oriented-execution	principle-prove-it-works	principle-redesign-from-first-principles	principle-replace-internal-apis-atomically	principle-separate-before-serializing-shared-state	principle-sequence-verifiable-units	principle-subtract-before-you-add	principle-test-behavior-not-implementation	principle-type-system-discipline	recall	reflect	regression-test	review-code-comments	safe-refactor	show-me-your-work	swarm	technical-writing	typescript-best-practices	unslop	why	worktree-cleanup	--global${expected_agent_fields}
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
grep -Fq $'https://github.com/petalas/skills.git\t--skill\tadversarial-review\tarchitect\tarena' "$log"

cat >"$fixture/duplicate.tsv" <<'EOF'
https://github.com/example/one.git	duplicated
https://github.com/example/two.git	duplicated
EOF
if DOTFILES_AI_SKILLS_CATALOG="$fixture/duplicate.tsv" install_ai_skills >/dev/null 2>"$fixture/duplicate.err"; then
    echo "Expected duplicate skills to be rejected" >&2
    exit 1
fi
grep -Fq 'Duplicate AI skill in catalog: duplicated' "$fixture/duplicate.err"

: >"$fixture/empty.tsv"
if DOTFILES_AI_SKILLS_CATALOG="$fixture/empty.tsv" install_ai_skills >/dev/null 2>"$fixture/empty.err"; then
    echo "Expected an empty catalog to be rejected" >&2
    exit 1
fi
grep -Fq 'AI skills catalog is empty' "$fixture/empty.err"

# Pruning removes agent links into the store that no longer resolve and leaves
# live links and links owned by anything else alone.
install_fake_skill kept
ln -s ../../.agents/skills/gone "$HOME/.claude/skills/gone"
ln -s ../../.agents/skills/gone "$HOME/.codex/skills/gone"
ln -s ../../../.agents/skills/gone "$HOME/.pi/agent/skills/gone"
ln -s ../../elsewhere/foreign "$HOME/.claude/skills/foreign"
prune_ai_skill_links >"$fixture/prune.out"
[[ -L "$HOME/.claude/skills/kept" && -e "$HOME/.claude/skills/kept" ]]
[[ ! -L "$HOME/.claude/skills/gone" && ! -L "$HOME/.codex/skills/gone" ]]
[[ ! -L "$HOME/.pi/agent/skills/gone" ]]
[[ -L "$HOME/.claude/skills/foreign" ]]
grep -Fq 'removing stale claude-code skill link: gone' "$fixture/prune.out"
grep -Fq 'removing stale codex skill link: gone' "$fixture/prune.out"
grep -Fq 'removing stale pi skill link: gone' "$fixture/prune.out"
rm -f "$HOME/.claude/skills/foreign"
ai_skill_present kept
if ai_skill_present gone; then
    echo "A skill without store files was reported present" >&2
    exit 1
fi
rm -f "$HOME/.pi/agent/skills/kept"
if ai_skill_present kept; then
    echo "A skill missing from an agent root was reported present" >&2
    exit 1
fi
install_fake_skill kept
rm -f "$HOME/.codex/skills/kept"
if ai_skill_present kept; then
    echo "A skill missing from the Codex root was reported present" >&2
    exit 1
fi
install_fake_skill kept

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

# The plan engine rejects the same malformed rows as the direct installer.
cat >"$skill_catalog/ai-skills.tsv" <<'EOF'
./relative/source	unslop
EOF
if DOTFILES_CATALOG_DIR="$skill_catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$fixture/invalid.plan" >/dev/null 2>"$fixture/invalid.err"; then
    echo "Expected the plan engine to reject an invalid AI skill source" >&2
    exit 1
fi
grep -Fq 'Invalid AI skill source on row 1: ./relative/source' "$fixture/invalid.err"
grep -Fq 'invalid AI skills catalog' "$fixture/invalid.err"
cat >"$skill_catalog/ai-skills.tsv" <<'EOF'
https://github.com/cursor/plugins.git	unslop
EOF

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
# source is recorded in the global skill lock and readable from every agent
# root. Stale links to skills outside the catalog are still pruned.
cat >"$HOME/.agents/.skill-lock.json" <<'EOF'
{
  "skills": {
    "alpha": { "sourceUrl": "https://github.com/example/one.git" },
    "beta": { "sourceUrl": "https://github.com/example/one.git" },
    "gamma": { "sourceUrl": "https://github.com/example/two.git" }
  }
}
EOF
for skill in alpha beta gamma; do install_fake_skill "$skill"; done
ln -s ../../.agents/skills/retired "$HOME/.claude/skills/retired"
: >"$log"
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
[[ ! -L "$HOME/.claude/skills/retired" ]] || {
    echo "Reconciliation left a stale skill link in place" >&2
    exit 1
}

# A lock entry whose files or agent links are missing is reconciled again, and
# only the affected skills of that source are fetched.
rm -f "$HOME/.claude/skills/beta"
rm -rf "$store/gamma"
: >"$log"
DOTFILES_CATALOG_DIR="$batch_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation reconcile --plan "$fixture/batch-skills.plan" >/dev/null
cat >"$fixture/expected-repair.log" <<EOF
--yes	skills	add	https://github.com/example/one.git	--skill	beta	--global${expected_agent_fields}
--yes	skills	add	https://github.com/example/two.git	--skill	gamma	--global${expected_agent_fields}
EOF
cmp -s "$fixture/expected-repair.log" "$log" || {
    diff -u "$fixture/expected-repair.log" "$log" >&2 || true
    exit 1
}
[[ ! -L "$HOME/.claude/skills/gamma" && ! -L "$HOME/.codex/skills/gamma" &&
    ! -L "$HOME/.pi/agent/skills/gamma" ]] || {
    echo "Reconciliation left links to a removed skill store entry" >&2
    exit 1
}
for skill in beta gamma; do install_fake_skill "$skill"; done

# A pinned catalog source is only satisfied by a lock entry recording that ref,
# and the pin is passed through to the CLI.
pinned_catalog="$fixture/pinned-catalog"
mkdir -p "$pinned_catalog/platforms"
cp "$skill_catalog/steps.tsv" "$skill_catalog/groups.tsv" "$skill_catalog/applications.tsv" "$pinned_catalog/"
cp "$skill_catalog/platforms/macos.tsv" "$pinned_catalog/platforms/macos.tsv"
cat >"$pinned_catalog/ai-skills.tsv" <<'EOF'
https://github.com/example/one.git#v2.0.0	alpha
https://github.com/example/one.git#v2.0.0	beta
https://github.com/example/two.git	gamma
EOF
DOTFILES_CATALOG_DIR="$pinned_catalog" "$repo_dir/lib/install-plan" prepare \
    --mode full --os macos --output "$fixture/pinned.plan" >/dev/null
grep -Fxq $'action\tai-skills.alpha\tai-skill\thttps://github.com/example/one.git#v2.0.0\talpha' "$fixture/pinned.plan"
cat >"$HOME/.agents/.skill-lock.json" <<'EOF'
{
  "skills": {
    "alpha": { "sourceUrl": "https://github.com/example/one.git", "ref": "v2.0.0" },
    "beta": { "sourceUrl": "https://github.com/example/one.git" },
    "gamma": { "sourceUrl": "https://github.com/example/two.git" }
  }
}
EOF
: >"$log"
DOTFILES_CATALOG_DIR="$pinned_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation reconcile --plan "$fixture/pinned.plan" >/dev/null
cat >"$fixture/expected-pinned.log" <<EOF
--yes	skills	add	https://github.com/example/one.git#v2.0.0	--skill	beta	--global${expected_agent_fields}
EOF
cmp -s "$fixture/expected-pinned.log" "$log" || {
    diff -u "$fixture/expected-pinned.log" "$log" >&2 || true
    exit 1
}

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
# The stubbed CLI leaves the store untouched; the removal path prunes links
# whose store entry is already gone.
install_fake_skill unslop
rm -rf "$store/unslop"
: >"$log"
DOTFILES_CATALOG_DIR="$skill_catalog" DOTFILES_INSTALL_PLAN_TRUSTED_TEST_PLAN=1 \
    "$repo_dir/lib/install-plan" execute --operation install --plan "$fixture/remove.plan" >/dev/null
cat >"$fixture/expected-ai-skill-remove.log" <<EOF
--yes	skills	remove	--global	--skill	unslop${expected_agent_fields}
EOF
cmp -s "$fixture/expected-ai-skill-remove.log" "$log"
[[ ! -L "$HOME/.claude/skills/unslop" && ! -L "$HOME/.codex/skills/unslop" &&
    ! -L "$HOME/.pi/agent/skills/unslop" ]] || {
    echo "Removal left stale skill links in agent roots" >&2
    exit 1
}

# The updater refreshes every global skill through the same CLI and prunes.
ln -s ../../.agents/skills/retired "$HOME/.claude/skills/retired"
: >"$log"
"$repo_dir/tools/update-ai-skills" >/dev/null
cat >"$fixture/expected-update.log" <<'EOF'
--yes	skills	update	--global	alpha	beta	gamma
EOF
cmp -s "$fixture/expected-update.log" "$log"
[[ ! -L "$HOME/.claude/skills/retired" ]]
if PATH="/usr/bin:/bin" "$repo_dir/tools/update-ai-skills" >/dev/null 2>"$fixture/update.err"; then
    echo "Expected the skills updater to fail without npx" >&2
    exit 1
fi
grep -Fq 'requires npx' "$fixture/update.err"

printf 'AI skills installer tests passed.\n'
"$node_bin" --test "$repo_dir/tests/test-ai-skill-updates.mjs"
