#!/usr/bin/env bash
# One result line per updated item, shared by update-dotfiles (Zsh) and its
# Bash helpers. Tool output stays on stdout/stderr, which the updater sends to
# its log. Result lines are copied to the log and to the terminal descriptor
# named by DOTFILES_UPDATE_TERMINAL_FD; without it they go to stdout only.
#
# A version snapshot is TSV: name, version, and 1 when the item is listed even
# if unchanged. Unlisted items (such as Homebrew dependencies) appear only when
# their version changes.

_update_report_tty() {
    [ -n "${DOTFILES_UPDATE_TERMINAL_FD:-}" ] && [ -t "$DOTFILES_UPDATE_TERMINAL_FD" ]
}

# Show a transient placeholder that the next result line or clear replaces.
update_report_progress() {
    _update_report_tty || return 0
    printf '\r\033[K\033[2mUpdating %s...\033[0m' "$1" >&"$DOTFILES_UPDATE_TERMINAL_FD"
}

update_report_clear() {
    _update_report_tty || return 0
    printf '\r\033[K' >&"$DOTFILES_UPDATE_TERMINAL_FD"
}

# update_report_result STATE NAME [OLD] [NEW]
# STATE is upgraded, installed, latest, failed, or skipped.
update_report_result() {
    local state=$1 name=$2 old=${3:-} new=${4:-} line color=
    local subject=$name
    [ -z "$old" ] || subject="$name $old"
    case "$state" in
        upgraded) line="Upgraded $subject ==> $new"; color='\033[32m' ;;
        installed) line="Installed $name $new"; color='\033[32m' ;;
        latest) line="$subject ==> already latest" ;;
        failed) line="$subject ==> failed to update"; color='\033[31m' ;;
        skipped) line="$subject ==> skipped"; color='\033[33m' ;;
        *) printf 'update report: invalid state: %s\n' "$state" >&2; return 2 ;;
    esac
    printf '%s\n' "$line"
    [ -n "${DOTFILES_UPDATE_TERMINAL_FD:-}" ] || return 0
    if _update_report_tty; then
        printf '\r\033[K%b%s\033[0m\n' "$color" "$line" >&"$DOTFILES_UPDATE_TERMINAL_FD"
    else
        printf '%s\n' "$line" >&"$DOTFILES_UPDATE_TERMINAL_FD"
    fi
}

# update_report_versions LABEL BEFORE AFTER STATUS
# A changed version is an upgrade whatever STATUS is. After a failed command an
# unchanged item has an unknown outcome, so only the item named LABEL (or the
# label itself) is reported as failed rather than listing items as current.
update_report_versions() {
    local label=$1 before=$2 after=$3 ok=0 state name old new sep
    # Records use the unit separator: read would merge empty tab-separated fields.
    sep=$(printf '\037')
    [ "$4" -ne 0 ] || ok=1
    awk -F '\t' -v OFS="$sep" -v ok="$ok" -v label="$label" '
        FILENAME == ARGV[1] { old[$1] = $2; listed[$1] = $3; next }
        {
            seen[$1] = 1
            if (!($1 in old)) {
                if ($3 == 1) print "installed", $1, "", $2
            } else if (old[$1] != $2) {
                print "upgraded", $1, old[$1], $2
            } else if (!ok && $1 == label) {
                print "failed", $1, $2, ""
            } else if (ok && (listed[$1] == 1 || $3 == 1)) {
                print "latest", $1, $2, ""
            }
        }
        END {
            if (!ok && !((label in old) && (label in seen))) print "failed", label, old[label], ""
        }
    ' "$before" "$after" | LC_ALL=C sort -f -t "$sep" -k2,2 |
        while IFS=$sep read -r state name old new; do
            update_report_result "$state" "$name" "$old" "$new"
        done
}

# update_batch LABEL SNAPSHOT COMMAND...
# Run COMMAND once and report each item from SNAPSHOT taken before and after.
# The `update_no_versions` snapshot reports only the label, and only on failure.
update_batch() {
    local label=$1 snapshot=$2 before after result=0
    shift 2
    update_report_progress "$label"
    before=$(mktemp "${TMPDIR:-/tmp}/dotfiles-update-before.XXXXXX") || return 1
    after=$(mktemp "${TMPDIR:-/tmp}/dotfiles-update-after.XXXXXX") || { rm -f "$before"; return 1; }
    if ! "$snapshot" >"$before"; then
        printf 'Could not read %s versions before updating.\n' "$label" >&2
        update_report_result failed "$label"
        rm -f "$before" "$after"
        return 1
    fi
    "$@" || result=$?
    if ! "$snapshot" >"$after"; then
        printf 'Could not read %s versions after updating.\n' "$label" >&2
        : >"$after"
        result=1
    fi
    update_report_versions "$label" "$before" "$after" "$result"
    update_report_clear
    rm -f "$before" "$after"
    return "$result"
}

update_no_versions() { :; }
