#!/usr/bin/env bash
# Shared package retry, filesystem, and platform helpers.

linux_distribution() {
    dotfiles_os
}

_linux_as_root() {
    run_as_root "$@"
}

_linux_install_root_file() {
    local source_file="$1"
    local destination="$2"
    local mode="${3:-0644}"

    _linux_as_root mkdir -p "$(dirname "$destination")" || return 1
    _linux_as_root install -m "$mode" "$source_file" "$destination"
}

_linux_files_differ() {
    if command -v cmp >/dev/null 2>&1; then
        ! cmp -s "$1" "$2"
    else
        [[ "$(cksum <"$1")" != "$(cksum <"$2")" ]]
    fi
}

_require_nonnegative_integer() {
    local name="$1"
    local value="$2"
    case "$value" in
        ''|*[!0-9]*)
            printf '%s must be a nonnegative integer: %s\n' "$name" "$value" >&2
            return 1
            ;;
    esac
}

_require_positive_integer() {
    _require_nonnegative_integer "$1" "$2" || return 1
    ((10#$2 > 0)) || {
        printf '%s must be greater than zero: %s\n' "$1" "$2" >&2
        return 1
    }
}

_run_batch_with_retries() {
    local callback="$1"
    shift
    local attempts="${DOTFILES_BATCH_RETRIES:-3}"
    local delay_seconds="${DOTFILES_BATCH_RETRY_DELAY_SECONDS:-2}"
    local attempt=1

    _require_positive_integer DOTFILES_BATCH_RETRIES "$attempts" || return 1
    _require_nonnegative_integer DOTFILES_BATCH_RETRY_DELAY_SECONDS "$delay_seconds" || return 1
    while ((attempt <= attempts)); do
        "$callback" "$@" && return 0
        if ((attempt < attempts)); then
            printf 'Package batch failed (attempt %d/%d); retrying: %s\n' \
                "$attempt" "$attempts" "$*" >&2
            sleep "$((delay_seconds * attempt))"
        fi
        ((attempt += 1))
    done
    return 1
}

# Try the efficient batch first. If it fails, retry each item independently so
# one unavailable package cannot block unrelated packages.
run_resilient_batch() {
    local label="$1"
    local callback="$2"
    shift 2
    local item
    local -a failed_items=()
    local IFS=', '

    (($#)) || return 0
    if _run_batch_with_retries "$callback" "$@"; then
        return 0
    fi
    if (($# == 1)); then
        failed_items+=("$1")
    else
        for item in "$@"; do
            _run_batch_with_retries "$callback" "$item" || failed_items+=("$item")
        done
    fi
    if ((${#failed_items[@]})); then
        printf 'Failed %s after retries: %s\n' "$label" "${failed_items[*]}" >&2
        return 1
    fi
}
