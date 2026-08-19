#!/usr/bin/env bash

# Link the managed per-vault settings when the selected vault already exists.
# Callers must source lib/link.sh first.
link_obsidian_vault_settings() {
    local dotfiles_dir="$1"
    local vault_dir="${OBSIDIAN_VAULT_DIR:-$HOME/git/notes}"

    if [[ ! -d "$vault_dir" ]]; then
        echo "Skipping Obsidian settings; vault not found: $vault_dir"
        return 0
    fi

    link_path \
        "$dotfiles_dir/dot/.config/obsidian/app.json" \
        "$vault_dir/.obsidian/app.json"
}
