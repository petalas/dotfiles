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
step	dependencies	on	Install dependencies
dependency	editors.neovim	foundation.git
outcome	foundation.git	ensure
outcome	editors.neovim	remove
outcome	communication.discord	force
outcome	gaming.steam	leave
EOF

go build -o "$fixture/dotfiles-tui" ./cmd/dotfiles-tui
"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/selection.tsv" --width 120 --display rich >"$fixture/rich"
grep -Fq 'Ensure 1' "$fixture/rich"
grep -Fq 'Leave 1' "$fixture/rich"
grep -Fq 'Remove 1' "$fixture/rich"
grep -Fq 'Force 1' "$fixture/rich"
grep -Fq 'custody warnings 1' "$fixture/rich"
grep -Fq 'enter review' "$fixture/rich"
grep -Fq '4 applications' "$fixture/rich"
grep -Fq 'Install dependencies' "$fixture/rich"

sed 's/outcome\teditors.neovim\tremove/outcome\teditors.neovim\tensure/' \
    "$fixture/selection.tsv" >"$fixture/compact-selection.tsv"
"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/compact-selection.tsv" --width 100 --display plain >"$fixture/compact"
if grep -Fq 'Evidence:' "$fixture/compact" || grep -Fq 'package present; launcher missing' "$fixture/compact"; then
    echo 'Compact mode must hide per-application evidence' >&2
    exit 1
fi
grep -Fq 'Git · present' "$fixture/compact"
grep -Fq 'Neovim · partial -> present' "$fixture/compact"
if grep -F 'Git · present' "$fixture/compact" | grep -Fq -- '->'; then
    echo 'Compact mode must omit transitions when current and desired states match' >&2
    exit 1
fi
"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/compact-selection.tsv" --width 100 --display plain --verbose >"$fixture/verbose"
grep -Fq 'Evidence: package present; launcher missing' "$fixture/verbose"
grep -Fq 'State: partial -> present' "$fixture/verbose"
grep -Fq 'Custody: managed' "$fixture/verbose"

sed -e 's/outcome\teditors.neovim\tremove/outcome\teditors.neovim\tensure/' \
    -e 's/outcome\tgaming.steam\tleave/outcome\tgaming.steam\tensure/' \
    "$fixture/selection.tsv" >"$fixture/color-selection.tsv"
"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/color-selection.tsv" --width 100 --display rich >"$fixture/colored"
COLORED_RENDER="$fixture/colored" python3 <<'PY'
import os
import re

content = open(os.environ["COLORED_RENDER"], "rb").read().splitlines()
styles = {}
for label, state in ((b"Git", b"present"), (b"Neovim", b"partial"), (b"Steam", b"absent")):
    line = next((candidate for candidate in content if label in candidate and state in candidate), None)
    if line is None:
        raise SystemExit(f"missing colored application line for {label.decode()}")
    codes = tuple(code for code in re.findall(rb"\x1b\[[0-9;:]*m", line) if code != b"\x1b[0m")
    if not codes:
        raise SystemExit(f"application/state is not colored for {label.decode()}: {line!r}")
    styles[label] = codes
if len(set(styles.values())) != len(styles):
    raise SystemExit("present, partial, and absent applications must use distinct state colors")
PY

"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/selection.tsv" --width 70 --display ascii >"$fixture/ascii"
LC_ALL=C grep -q '^[ -~]*$' "$fixture/ascii"
grep -Fq '[!]' "$fixture/ascii"
grep -Fq 'APPLICATIONS (4)  item 1/4' "$fixture/ascii"
grep -Fq 'e/u/r/f set item outcome' "$fixture/ascii"
if grep -Fq 'left/right lane' "$fixture/ascii"; then
    echo 'Stable planning list must not advertise outcome lanes as navigation' >&2
    exit 1
fi

cat >"$fixture/events" <<'EOF'
#!/usr/bin/env bash
event_fd=${DOTFILES_INSTALL_PLAN_EVENT_FD:-1}
printf 'event\t1\trun-start\t2\n' >&"$event_fd"
printf 'event\t1\toperation-start\tapp:one\tOne\tindeterminate\n' >&"$event_fd"
printf 'event\t1\toperation-settled\tapp:one\tsucceeded\t1\t2\n' >&"$event_fd"
printf 'event\t1\toperation-start\tstep:links\tLinks\tindeterminate\n' >&"$event_fd"
printf 'event\t1\toperation-settled\tstep:links\tsucceeded\t2\t2\n' >&"$event_fd"
printf 'event\t1\trun-settled\tsucceeded\t2\t2\n' >&"$event_fd"
EOF
chmod +x "$fixture/events"
TERM=xterm "$fixture/dotfiles-tui" run -- "$fixture/events" >"$fixture/run"
grep -Fq '[RUN]' "$fixture/run"
grep -Fq 'Ensure · Leave · Remove · Force' "$fixture/run"
grep -Fq '2/2 settled' "$fixture/run"
grep -Fq 'One — succeeded' "$fixture/run"
grep -Fq 'Run settled successfully' "$fixture/run"

cat >"$fixture/event-shaped-log" <<'EOF'
#!/usr/bin/env bash
event_fd=${DOTFILES_INSTALL_PLAN_EVENT_FD:-1}
printf 'event\t1\trun-start\t1\n' >&"$event_fd"
printf 'event\tHomebrew diagnostic that is not a protocol record\n'
printf 'event\t1\toperation-start\tapp:one\tOne\tindeterminate\n' >&"$event_fd"
printf 'event\t1\toperation-settled\tapp:one\tsucceeded\t1\t1\n' >&"$event_fd"
printf 'event\t1\trun-settled\tsucceeded\t1\t1\n' >&"$event_fd"
EOF
chmod +x "$fixture/event-shaped-log"
TERM=xterm "$fixture/dotfiles-tui" run -- "$fixture/event-shaped-log" >"$fixture/collision-run"
grep -Fq 'Run settled successfully' "$fixture/collision-run"
grep -Fq 'Homebrew diagnostic' "$fixture/collision-run"

cat >"$fixture/bad-events" <<'EOF'
#!/usr/bin/env bash
event_fd=${DOTFILES_INSTALL_PLAN_EVENT_FD:-1}
printf 'event\t2\trun-start\t1\n' >&"$event_fd"
EOF
chmod +x "$fixture/bad-events"
if TERM=xterm "$fixture/dotfiles-tui" run -- "$fixture/bad-events" >"$fixture/bad-run" 2>&1; then
    echo 'Expected malformed execution events to fail closed' >&2
    exit 1
fi
grep -Fq 'malformed execution event' "$fixture/bad-run"
grep -Fq 'event\t2\trun-start\t1' "$fixture/bad-run"

printf 'Stable-list TUI and progress rendering tests passed.\n'
