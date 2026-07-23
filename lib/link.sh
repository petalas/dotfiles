#!/usr/bin/env bash

# Replace TARGET with an absolute symlink to SOURCE.
#
# Existing targets (including directories and broken symlinks) are moved to
# TARGET.old. The replacement link is prepared before the target is touched,
# and a failed final move restores the previous target when possible.
link_path() {
    local source="$1"
    local target="$2"
    local parent backup pending had_target=false

    if [[ ! -e "$source" ]]; then
        echo "Cannot link missing source: $source" >&2
        return 1
    fi

    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        return 0
    fi

    parent=$(dirname "$target")
    if ! mkdir -p "$parent"; then
        echo "Cannot create link parent: $parent" >&2
        return 1
    fi

    backup="$target.old"
    pending="$target.new.$$"

    # Clean up debris from an interrupted run with the same PID namespace.
    if ! rm -rf "$pending"; then
        echo "Cannot remove stale pending link: $pending" >&2
        return 1
    fi
    if ! ln -s "$source" "$pending"; then
        echo "Cannot prepare link: $source -> $target" >&2
        return 1
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        had_target=true
        if ! rm -rf "$backup"; then
            rm -f "$pending"
            echo "Cannot replace stale backup: $backup" >&2
            return 1
        fi
        if ! mv "$target" "$backup"; then
            rm -f "$pending"
            echo "Cannot back up link target: $target" >&2
            return 1
        fi
        echo "Created backup: $backup"
    fi

    if ! mv "$pending" "$target"; then
        rm -f "$pending"
        echo "Cannot install link: $source -> $target" >&2
        if [[ "$had_target" == true && ! -e "$target" && ! -L "$target" ]]; then
            if mv "$backup" "$target"; then
                echo "Restored previous target: $target" >&2
            else
                echo "Could not restore $target; backup remains at $backup" >&2
            fi
        fi
        return 1
    fi

    echo "Linked $source -> $target"
}
