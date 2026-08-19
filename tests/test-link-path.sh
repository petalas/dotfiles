#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/link.sh
source "$repo_dir/lib/link.sh"
# shellcheck source=lib/obsidian.sh
source "$repo_dir/lib/obsidian.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
source_file="$fixture/source file"
target="$fixture/nested dir/target"
printf 'managed\n' > "$source_file"

fail() {
    echo "link_path test failed: $*" >&2
    exit 1
}

assert_managed_link() {
    [[ -L "$target" ]] || fail "target is not a symlink"
    [[ "$(readlink "$target")" == "$source_file" ]] ||
        fail "target does not point to the managed source"
}

# Missing parents are created and paths containing spaces are supported.
link_path "$source_file" "$target"
assert_managed_link

# A correct link is a no-op and must not rotate an existing backup.
printf 'keep backup\n' > "$target.old"
link_path "$source_file" "$target"
[[ "$(cat "$target.old")" == "keep backup" ]] || fail "idempotent run changed backup"

# Regular files are preserved as the latest backup.
rm "$target"
printf 'local file\n' > "$target"
link_path "$source_file" "$target"
assert_managed_link
[[ -f "$target.old" && "$(cat "$target.old")" == "local file" ]] ||
    fail "regular file was not backed up"

# Directories replace any stale backup without being copied or followed.
rm "$target"
mkdir "$target"
printf 'inside\n' > "$target/value"
rm -rf "$target.old"
mkdir -p "$target.old/stale"
link_path "$source_file" "$target"
assert_managed_link
[[ -f "$target.old/value" && ! -e "$target.old/stale" ]] ||
    fail "directory was not moved cleanly to backup"

# Wrong and broken symlinks are backed up as symlinks, not dereferenced.
rm "$target"
ln -s "$fixture/other" "$target"
link_path "$source_file" "$target"
assert_managed_link
[[ -L "$target.old" && "$(readlink "$target.old")" == "$fixture/other" ]] ||
    fail "wrong symlink was not preserved"

rm "$target"
ln -s "$fixture/missing" "$target"
link_path "$source_file" "$target"
assert_managed_link
[[ -L "$target.old" && "$(readlink "$target.old")" == "$fixture/missing" ]] ||
    fail "broken symlink was not preserved"

# A missing source fails before changing an existing target.
rm "$target"
printf 'untouched\n' > "$target"
if link_path "$fixture/does-not-exist" "$target"; then
    fail "missing source unexpectedly succeeded"
fi
[[ ! -L "$target" && "$(cat "$target")" == "untouched" ]] ||
    fail "missing source changed target"

# The managed Obsidian vault config is valid and honors the vault override.
obsidian_source="$repo_dir/dot/.config/obsidian/app.json"
obsidian_target="$fixture/notes/.obsidian/app.json"
jq -e '.alwaysUpdateLinks == true' "$obsidian_source" >/dev/null ||
    fail "managed Obsidian config does not enable automatic link updates"
mkdir -p "$fixture/notes"
OBSIDIAN_VAULT_DIR="$fixture/notes" link_obsidian_vault_settings "$repo_dir"
[[ -L "$obsidian_target" && "$(readlink "$obsidian_target")" == "$obsidian_source" ]] ||
    fail "Obsidian config was not linked into the vault"
jq -e '.alwaysUpdateLinks == true' "$obsidian_target" >/dev/null ||
    fail "linked Obsidian config changed semantics"

missing_vault="$fixture/missing-vault"
OBSIDIAN_VAULT_DIR="$missing_vault" link_obsidian_vault_settings "$repo_dir" >/dev/null
[[ ! -e "$missing_vault" ]] || fail "missing Obsidian vault was created"

printf 'link_path state-transition tests passed.\n'
