#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if ! command -v go >/dev/null 2>&1; then
    printf 'Go unavailable; release reproducibility test skipped.\n'
    exit 0
fi
fixture=$(mktemp -d /tmp/dotfiles-tui-release.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
for target in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64; do
    os=${target%/*}; arch=${target#*/}; platform=$os
    [[ "$os" != darwin ]] || platform=macos
    artifact="$fixture/dotfiles-tui-$platform-$arch"
    CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -trimpath -ldflags='-s -w -buildid=' \
        -o "$artifact" ./cmd/dotfiles-tui
    if command -v sha256sum >/dev/null; then actual=$(sha256sum "$artifact" | awk '{print $1}'); else actual=$(shasum -a 256 "$artifact" | awk '{print $1}'); fi
    expected=$(awk -F '\t' -v platform="$platform" -v arch="$arch" \
        '$1=="artifact" && $2==platform && $3==arch {print $4}' catalog/tui-releases.tsv)
    [[ "$actual" == "$expected" ]] || {
        echo "TUI release manifest drifted for $platform/$arch" >&2
        exit 1
    }
done
printf 'TUI release manifest reproducibility tests passed.\n'
