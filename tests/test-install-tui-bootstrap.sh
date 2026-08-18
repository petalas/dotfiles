#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d /tmp/dotfiles-tui-bootstrap.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
cat >"$fixture/artifact" <<'EOF'
#!/usr/bin/env bash
printf 'verified helper: %s\n' "$*"
EOF
chmod +x "$fixture/artifact"
if command -v sha256sum >/dev/null; then digest=$(sha256sum "$fixture/artifact" | awk '{print $1}'); else digest=$(shasum -a 256 "$fixture/artifact" | awk '{print $1}'); fi
case "$(uname -s)" in Darwin) platform=macos ;; Linux) platform=linux ;; esac
case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; esac
printf 'format\t1\nversion\ttest-v1\nartifact\t%s\t%s\t%s\tfile://%s\n' \
    "$platform" "$arch" "$digest" "$fixture/artifact" >"$fixture/manifest.tsv"
DOTFILES_TUI_MANIFEST="$fixture/manifest.tsv" XDG_CACHE_HOME="$fixture/cache" \
    "$repo_dir/tools/run-install-tui" render --width 80 >"$fixture/first"
grep -Fxq 'verified helper: render --width 80' "$fixture/first"
cached="$fixture/cache/dotfiles/tui/test-v1/$platform-$arch/dotfiles-tui"
printf 'corrupt\n' >"$cached"; chmod +x "$cached"
DOTFILES_TUI_MANIFEST="$fixture/manifest.tsv" XDG_CACHE_HOME="$fixture/cache" \
    "$repo_dir/tools/run-install-tui" confirm --plan example >"$fixture/second"
grep -Fxq 'verified helper: confirm --plan example' "$fixture/second"
printf 'Prebuilt TUI verification tests passed.\n'
