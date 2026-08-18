#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
if ! command -v go >/dev/null 2>&1; then
    printf 'Go unavailable; install TUI source tests skipped (runtime uses prebuilt binaries).\n'
    exit 0
fi
fixture=$(mktemp -d /tmp/dotfiles-install-tui.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
cat >"$fixture/observations.tsv" <<'EOF'
format	1
os	macos
observation	foundation.git	available	present	managed	required	disabled	disabled	foundation	Git	registered by Homebrew
observation	editors.neovim	available	partial	managed	optional	enabled	disabled	editors	Neovim	package present; launcher missing
observation	communication.discord	available	present	unverified	optional	disabled	enabled	communication	Discord	found without receipt
observation	gaming.steam	available	absent	unverified	optional	disabled	disabled	gaming	Steam	not registered
EOF
cat >"$fixture/selection.tsv" <<'EOF'
format	1
outcome	foundation.git	ensure
outcome	editors.neovim	remove
outcome	communication.discord	force
outcome	gaming.steam	leave
EOF

go build -o "$fixture/dotfiles-tui" ./cmd/dotfiles-tui
"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/selection.tsv" --width 120 --display rich >"$fixture/rich"
grep -Fq 'ENSURE PRESENT' "$fixture/rich"
grep -Fq 'LEAVE UNCHANGED' "$fixture/rich"
grep -Fq 'REMOVE' "$fixture/rich"
grep -Fq 'FORCE REMOVAL' "$fixture/rich"
grep -Fq 'Discord' "$fixture/rich"
grep -Fq 'unverified' "$fixture/rich"
grep -Fq '4 applications' "$fixture/rich"

"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/selection.tsv" --width 70 --display ascii >"$fixture/ascii"
LC_ALL=C grep -q '^[ -~]*$' "$fixture/ascii"
grep -Fq '[!]' "$fixture/ascii"
grep -Fq 'Lane 1/4' "$fixture/ascii"

cat >"$fixture/events" <<'EOF'
#!/usr/bin/env bash
printf 'event\t1\trun-start\t2\n'
printf 'event\t1\toperation-start\tapp:one\tOne\tindeterminate\n'
printf 'event\t1\toperation-settled\tapp:one\tsucceeded\t1\t2\n'
printf 'event\t1\toperation-start\tstep:links\tLinks\tindeterminate\n'
printf 'event\t1\toperation-settled\tstep:links\tsucceeded\t2\t2\n'
printf 'event\t1\trun-settled\tsucceeded\t2\t2\n'
EOF
chmod +x "$fixture/events"
TERM=xterm "$fixture/dotfiles-tui" run -- "$fixture/events" >"$fixture/run"
grep -Fq '2/2 settled' "$fixture/run"
grep -Fq 'One — succeeded' "$fixture/run"
grep -Fq 'Run settled successfully' "$fixture/run"

printf 'Intent-lanes TUI and progress rendering tests passed.\n'
