#!/usr/bin/env bash

_ai_skills_catalog_path() {
    printf '%s\n' "${DOTFILES_AI_SKILLS_CATALOG:-${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/catalog/ai-skills.tsv}"
}

_ai_skill_valid_source() {
    case "$1" in
        ''|-*|*[[:space:]]*) return 1 ;;
        http://*|https://*|git@*:*|[A-Za-z0-9_.-]*/*) return 0 ;;
        *) return 1 ;;
    esac
}

_ai_skill_valid_name() {
    [[ "$1" =~ ^[a-z0-9][a-z0-9.-]*$ ]]
}

_ai_skill_source_seen() {
    local needle=$1 value
    shift
    for value in "$@"; do
        [[ "$value" == "$needle" ]] && return 0
    done
    return 1
}

_load_ai_skills_catalog() {
    local catalog line_number=0 source skill extra index
    catalog=$(_ai_skills_catalog_path)
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
        if ! _ai_skill_valid_source "$source"; then
            echo "Invalid AI skill source on row $line_number: $source" >&2
            return 1
        fi
        if ! _ai_skill_valid_name "$skill"; then
            echo "Invalid AI skill name on row $line_number: $skill" >&2
            return 1
        fi
        index=0
        while ((index < ${#ai_skill_names[@]})); do
            if [[ "${ai_skill_names[$index]}" == "$skill" ]]; then
                echo "Duplicate AI skill in catalog: $skill" >&2
                return 1
            fi
            index=$((index + 1))
        done
        ai_skill_sources+=("$source")
        ai_skill_names+=("$skill")
    done <"$catalog"
    if ((${#ai_skill_names[@]} == 0)); then
        echo "AI skills catalog is empty: $catalog" >&2
        return 1
    fi
}

install_ai_skills() {
    local index source skill_index result=0
    local -a handled_sources source_skills
    _load_ai_skills_catalog || return 1
    command -v npx >/dev/null 2>&1 || {
        echo "AI skills installation requires npx; install Node first." >&2
        return 1
    }

    handled_sources=()
    index=0
    while ((index < ${#ai_skill_sources[@]})); do
        source=${ai_skill_sources[$index]}
        if ((${#handled_sources[@]})) && _ai_skill_source_seen "$source" "${handled_sources[@]}"; then
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
        if ! npx --yes skills add "$source" --skill "${source_skills[@]}" --global --agent '*' --yes </dev/null; then
            echo "Failed to install AI skills from $source" >&2
            result=1
        fi
        index=$((index + 1))
    done
    return "$result"
}
