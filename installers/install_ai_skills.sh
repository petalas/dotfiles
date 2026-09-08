#!/usr/bin/env bash
# Curated global AI agent skills. This module owns the catalog format, the
# targeted agent runtimes and their skill roots, and every `skills` CLI call;
# lib/install-plan, tools/update-ai-skills, and ./install ai_skills reuse it.

ai_skills_catalog_path() {
    printf '%s\n' "${DOTFILES_AI_SKILLS_CATALOG:-${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/catalog/ai-skills.tsv}"
}

# Accept git URLs and GitHub `owner/repo` shorthand, optionally pinned with a
# `#<ref>` suffix (branch, tag, or full commit SHA) that `skills add` and
# `skills update` honour. Both shorthand segments must start with an
# alphanumeric so relative paths such as `./x` or `a/../b` never reach the CLI.
ai_skill_valid_source() {
    local repo ref=
    case "$1" in
        ''|-*|*[[:space:]]*|*'#'*'#'*) return 1 ;;
    esac
    repo=${1%%#*}
    [[ "$repo" == "$1" ]] || ref=${1#*#}
    [[ "$1" != *'#'* || "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || return 1
    case "$repo" in
        http://*|https://*|git@*:*) return 0 ;;
    esac
    [[ "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]
}

# Split a catalog source into the repository the lock records as `sourceUrl`
# (without `.git`) and its pinned ref, if any.
ai_skill_source_repo() {
    local repo=${1%%#*}
    printf '%s\n' "${repo%.git}"
}

ai_skill_source_ref() {
    [[ "$1" == *'#'* ]] && printf '%s\n' "${1#*#}"
    return 0
}

ai_skill_valid_name() {
    [[ "$1" =~ ^[a-z0-9][a-z0-9.-]*$ ]]
}

_ai_skill_value_seen() {
    local needle=$1 value
    shift
    for value in "$@"; do
        [[ "$value" == "$needle" ]] && return 0
    done
    return 1
}

# Load `source<TAB>skill` rows into ai_skill_sources/ai_skill_names. Blank
# lines and `#` comments are ignored; malformed or duplicate rows fail.
load_ai_skills_catalog() {
    local catalog=${1:-$(ai_skills_catalog_path)} line_number=0 source skill extra
    ai_skill_sources=()
    ai_skill_names=()
    [[ -r "$catalog" ]] || {
        echo "AI skills catalog is missing: $catalog" >&2
        return 1
    }
    while IFS=$'\t' read -r source skill extra; do
        line_number=$((line_number + 1))
        [[ -n "$source$skill${extra:-}" ]] || continue
        case "$source" in \#*) continue ;; esac
        if [[ -z "$source" || -z "$skill" || -n "${extra:-}" ]]; then
            echo "Malformed AI skills catalog row $line_number: expected source<TAB>skill" >&2
            return 1
        fi
        if ! ai_skill_valid_source "$source"; then
            echo "Invalid AI skill source on row $line_number: $source" >&2
            return 1
        fi
        if ! ai_skill_valid_name "$skill"; then
            echo "Invalid AI skill name on row $line_number: $skill" >&2
            return 1
        fi
        if ((${#ai_skill_names[@]})) && _ai_skill_value_seen "$skill" "${ai_skill_names[@]}"; then
            echo "Duplicate AI skill in catalog: $skill" >&2
            return 1
        fi
        ai_skill_sources+=("$source")
        ai_skill_names+=("$skill")
    done <"$catalog"
}

# Targeted runtimes and the global skill root each one reads. `universal`
# owns the canonical store; the others hold symlinks into it. See
# docs/LEARNINGS.md "Global AI skill installs should target owned runtimes".
ai_skill_global_agents() {
    printf '%s\n' claude-code pi universal
}

ai_skill_agent_root() {
    case "$1" in
        claude-code) printf '%s\n' "$HOME/.claude/skills" ;;
        pi) printf '%s\n' "$HOME/.pi/agent/skills" ;;
        universal) printf '%s\n' "$HOME/.agents/skills" ;;
        *) echo "Unknown AI skill agent: $1" >&2; return 1 ;;
    esac
}

ai_skill_store_path() {
    ai_skill_agent_root universal
}

ai_skill_lock_path() {
    printf '%s\n' "${DOTFILES_AI_SKILLS_LOCK:-$HOME/.agents/.skill-lock.json}"
}

# A skill counts as installed only when its files exist in the store and every
# targeted agent root can reach them; the lock alone is not sufficient.
ai_skill_present() {
    local skill=$1 agent root
    while IFS= read -r agent; do
        root=$(ai_skill_agent_root "$agent")
        [[ -f "$root/$skill/SKILL.md" ]] || return 1
    done < <(ai_skill_global_agents)
}

# Remove symlinks in agent roots that point into the store but no longer
# resolve, e.g. after a skill left the catalog. Other entries are untouched.
prune_ai_skill_links() {
    local agent root link target store
    store=$(ai_skill_store_path)
    while IFS= read -r agent; do
        root=$(ai_skill_agent_root "$agent")
        [[ "$root" != "$store" && -d "$root" ]] || continue
        for link in "$root"/* "$root"/.[!.]*; do
            [[ -L "$link" && ! -e "$link" ]] || continue
            target=$(readlink "$link") || continue
            case "$target" in
                "$store"/*|*/.agents/skills/*) ;;
                *) continue ;;
            esac
            printf ':: removing stale %s skill link: %s\n' "$agent" "${link##*/}"
            rm -f -- "$link"
        done
    done < <(ai_skill_global_agents)
}

ai_skills_cli() {
    command -v npx >/dev/null 2>&1 || {
        echo "AI skills management requires npx; install Node first." >&2
        return 1
    }
    npx --yes skills "$@" </dev/null
}

install_ai_skill_batch() {
    local source=$1 agent
    shift
    local -a agents
    agents=()
    while IFS= read -r agent; do agents+=("$agent"); done < <(ai_skill_global_agents)
    ai_skills_cli add "$source" --skill "$@" --global --agent "${agents[@]}" --yes
}

remove_ai_skill_global() {
    local skill=$1 agent
    local -a agents
    agents=()
    while IFS= read -r agent; do agents+=("$agent"); done < <(ai_skill_global_agents)
    ai_skills_cli remove --global --skill "$skill" --agent "${agents[@]}" --yes
}

update_ai_skills_global() {
    ai_skills_cli update --global
}

install_ai_skills() {
    local index source skill_index result=0
    local -a handled_sources source_skills
    load_ai_skills_catalog || return 1
    if ((${#ai_skill_names[@]} == 0)); then
        echo "AI skills catalog is empty: $(ai_skills_catalog_path)" >&2
        return 1
    fi
    command -v npx >/dev/null 2>&1 || {
        echo "AI skills installation requires npx; install Node first." >&2
        return 1
    }

    handled_sources=()
    index=0
    while ((index < ${#ai_skill_sources[@]})); do
        source=${ai_skill_sources[$index]}
        if ((${#handled_sources[@]})) && _ai_skill_value_seen "$source" "${handled_sources[@]}"; then
            index=$((index + 1))
            continue
        fi
        handled_sources+=("$source")
        source_skills=()
        skill_index=0
        while ((skill_index < ${#ai_skill_names[@]})); do
            if [[ "${ai_skill_sources[$skill_index]}" == "$source" ]]; then
                source_skills+=("${ai_skill_names[$skill_index]}")
            fi
            skill_index=$((skill_index + 1))
        done
        printf ':: installing global AI skills from %s: %s\n' "$source" "${source_skills[*]}"
        if ! install_ai_skill_batch "$source" "${source_skills[@]}"; then
            echo "Failed to install AI skills from $source" >&2
            result=1
        fi
        index=$((index + 1))
    done
    prune_ai_skill_links
    return "$result"
}
