#!/usr/bin/env bash
# Homebrew helpers shared by macOS setup (Bash) and the Zsh update command.

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _homebrew_file=${BASH_SOURCE[0]}
else
    _homebrew_file=$(print -P '%N')
fi
# shellcheck source=update-report.sh
source "$(cd "$(dirname "$_homebrew_file")" && pwd)/update-report.sh"
unset _homebrew_file

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

# The docker-desktop cask upgrade deletes Docker's privileged helpers. Docker's
# own installer restores them headlessly; otherwise the next launch shows an
# administrator password dialog.
_homebrew_restore_docker_helpers() {
    local installer="${DOCKER_DESKTOP_INSTALLER:-/Applications/Docker.app/Contents/MacOS/install}"

    if ! sudo -n true 2>/dev/null; then
        printf 'Note: passwordless sudo is unavailable; Docker Desktop will ask for an administrator password on next launch.\n' >&2
        return 0
    fi
    sudo -n "$installer" config --user "$USER" </dev/null
}

_homebrew_docker_running() {
    [[ $(osascript -e 'application id "com.docker.docker" is running' 2>/dev/null) == true ]]
}

# Homebrew reopens apps it quit during an upgrade, before upd can restore
# Docker's helpers. Docker then finds them missing, prompts for a password, and
# its own repair collides with the restore. Stopping Docker first stops
# Homebrew from reopening it. Docker's CLI waits for a clean VM shutdown; an
# Apple Event quit during startup kills the VM.
_homebrew_quit_docker() {
    docker desktop stop --timeout 60 </dev/null && ! _homebrew_docker_running
}

# Print "kind<TAB>name<TAB>installed<TAB>latest<TAB>pinned" for each entry
# that upd would change, then "kind<TAB>name<TAB>installed" for each formula
# installed on request and each cask. Dependencies appear only when outdated.
_homebrew_upgrade_candidates() {
    local outdated requested formulae casks
    outdated=$(brew outdated --json=v2) || return 1
    requested=$(brew list --formula --installed-on-request) || return 1
    formulae=$(brew list --formula --versions) || return 1
    casks=$(brew list --cask --versions) || return 1
    printf '%s\n' "$outdated" | jq -r '
        def newest: if type == "array" then .[-1] else . end;
        (.formulae[] | ["formula", .name, (.installed_versions | newest), .current_version, (.pinned // false)]),
        (.casks[] | ["cask", .name, (.installed_versions | newest), .current_version, false])
        | map(tostring) | @tsv' || return 1
    {
        printf '%s\n' "$requested"
        printf '%s\n' '--formulae--'
        printf '%s\n' "$formulae"
        printf '%s\n' '--casks--'
        printf '%s\n' "$casks"
    } | awk -v OFS='\t' '
        $0 == "--formulae--" { section = "formula"; next }
        $0 == "--casks--" { section = "cask"; next }
        section == "" { if ($1 != "") requested[$1] = 1; next }
        section == "formula" && requested[$1] { print "formula", $1, $NF }
        section == "cask" && $1 != "" { print "cask", $1, $NF }
    '
}

# Upgrade each outdated entry separately so one broken package cannot hide the
# rest, and report one result line per entry.
homebrew_upgrade_individually() {
    local candidates kind name installed latest pinned is_docker reopen_docker
    local failed=0

    if ! candidates=$(_homebrew_upgrade_candidates); then
        _homebrew_report_failure "listing Homebrew packages"
        update_report_result failed Homebrew
        return 1
    fi
    # Outdated records come first; keep them over the plain installed record.
    while IFS=$'\t' read -r kind name installed latest pinned; do
        [[ -n "$name" ]] || continue
        if [[ -z "$latest" ]]; then
            update_report_result latest "$name" "$installed"
            continue
        fi
        if [[ "$pinned" == true ]]; then
            printf 'Skipping pinned Homebrew %s %s.\n' "$kind" "$name"
            update_report_result skipped "$name" "$installed"
            continue
        fi
        update_report_progress "$name"
        printf '\nUpgrading Homebrew %s %s...\n' "$kind" "$name"
        is_docker=0 reopen_docker=0
        [[ "$kind" == cask && "$name" == docker-desktop ]] && is_docker=1
        if ((is_docker)) && _homebrew_docker_running; then
            if ! _homebrew_quit_docker; then
                _homebrew_report_failure "quitting Docker Desktop before its upgrade"
                update_report_result failed "$name" "$installed"
                failed=1
                continue
            fi
            reopen_docker=1
        fi
        if ! brew upgrade "--$kind" "$name" </dev/null; then
            _homebrew_report_failure "Homebrew $kind $name"
            update_report_result failed "$name" "$installed"
            failed=1
        else
            update_report_result upgraded "$name" "$installed" "$latest"
            if ((is_docker)) && ! _homebrew_restore_docker_helpers; then
                _homebrew_report_failure "Docker Desktop privileged helpers"
                update_report_result failed "Docker Desktop privileged helpers"
                failed=1
            fi
        fi
        if ((reopen_docker)); then
            open -b com.docker.docker || failed=1
        fi
    done < <(printf '%s\n' "$candidates" | awk -F '\t' '!seen[$1 FS $2]++' | LC_ALL=C sort -f -t "$(printf '\t')" -k2,2)

    return "$failed"
}
