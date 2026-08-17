#!/usr/bin/env bash
# Homebrew helpers shared by macOS setup (Bash) and the Zsh update command.

_homebrew_report_failure() {
    printf 'Warning: %s failed; continuing with other Homebrew entries.\n' "$1" >&2
}

# Copy one active declaration exactly as written so options such as
# `trusted: true` survive isolated fallback installation.
_homebrew_extract_entry() {
    local brewfile="$1"
    local kind="$2"
    local entry="$3"
    local destination="$4"
    local directive

    case "$kind" in
        tap) directive=tap ;;
        formula) directive=brew ;;
        cask) directive=cask ;;
        *) return 1 ;;
    esac

    awk -v directive="$directive" -v expected="$entry" '
        {
            line = $0
            trimmed = line
            sub(/^[[:space:]]*/, "", trimmed)
            prefix = directive " \""
            if (index(trimmed, prefix) != 1) next
            value = substr(trimmed, length(prefix) + 1)
            sub(/\".*/, "", value)
            if (value == expected) {
                print trimmed
                found = 1
                exit
            }
        }
        END { if (!found) exit 1 }
    ' "$brewfile" >"$destination"
}

homebrew_bundle_install_resilient() {
    local brewfile="$1"
    local kind entries entry entry_file
    local failed=0

    if brew bundle --no-upgrade --file="$brewfile"; then
        return 0
    fi

    printf 'Brewfile reconciliation failed; retrying active entries individually.\n' >&2
    for kind in tap formula cask; do
        if ! entries=$(brew bundle list "--$kind" --file="$brewfile"); then
            _homebrew_report_failure "listing Brewfile $kind entries"
            failed=1
            continue
        fi
        while IFS= read -r entry; do
            [[ -n "$entry" ]] || continue
            entry_file=$(mktemp "${TMPDIR:-/tmp}/dotfiles-Brewfile.XXXXXX") || return 1
            if ! _homebrew_extract_entry "$brewfile" "$kind" "$entry" "$entry_file"; then
                rm -f "$entry_file"
                _homebrew_report_failure "finding Brewfile $kind $entry with its options"
                failed=1
                continue
            fi
            if brew bundle check --file="$entry_file" >/dev/null 2>&1; then
                rm -f "$entry_file"
                continue
            fi
            if ! brew bundle --no-upgrade --file="$entry_file"; then
                _homebrew_report_failure "Brewfile $kind $entry"
                failed=1
            fi
            rm -f "$entry_file"
        done <<<"$entries"
    done

    return "$failed"
}

homebrew_upgrade_individually() {
    local kind entries entry
    local failed=0

    for kind in formula cask; do
        if ! entries=$(brew outdated "--$kind" --quiet); then
            _homebrew_report_failure "listing outdated Homebrew ${kind}s"
            failed=1
            continue
        fi
        while IFS= read -r entry; do
            [[ -n "$entry" ]] || continue
            printf '\nUpgrading Homebrew %s %s...\n' "$kind" "$entry"
            if ! brew upgrade "--$kind" "$entry"; then
                _homebrew_report_failure "Homebrew $kind $entry"
                failed=1
            fi
        done <<<"$entries"
    done

    return "$failed"
}
