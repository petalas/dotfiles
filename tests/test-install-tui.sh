#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
if ! command -v go >/dev/null 2>&1; then
    printf 'Go unavailable; install TUI source tests skipped (runtime uses prebuilt binaries).\n'
    exit 0
fi
fixture=$(mktemp -d /tmp/dotfiles-install-tui.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
export XDG_STATE_HOME="$fixture/state"
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
group	foundation	Foundation
group	editors	Editors & IDEs
group	communication	Browsers & communication
group	gaming	Gaming & streaming
step	dependencies	on	Install dependencies
dependency	editors.neovim	foundation.git
outcome	foundation.git	ensure
outcome	editors.neovim	remove
outcome	communication.discord	remove
outcome	gaming.steam	leave
EOF

go build -o "$fixture/dotfiles-tui" ./cmd/dotfiles-tui
"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/selection.tsv" --width 120 --display rich >"$fixture/rich"
grep -Fq 'Ensure 1' "$fixture/rich"
grep -Fq 'Leave 1' "$fixture/rich"
grep -Fq 'Remove 2' "$fixture/rich"
if grep -Fq 'Force' "$fixture/rich"; then
    echo 'Planning must not expose Force as a separate outcome' >&2
    exit 1
fi
grep -Fq 'custody warnings 1' "$fixture/rich"
grep -Fq 'enter review' "$fixture/rich"
grep -Fq '4 applications' "$fixture/rich"
grep -Fq 'Install dependencies' "$fixture/rich"

sed $'s/outcome\tcommunication.discord\tremove/outcome\tcommunication.discord\tforce/' \
    "$fixture/selection.tsv" >"$fixture/legacy-force-selection.tsv"
"$fixture/dotfiles-tui" render --observations "$fixture/observations.tsv" \
    --selection "$fixture/legacy-force-selection.tsv" --width 120 --display plain >"$fixture/legacy-force"
grep -Fq 'Remove 2' "$fixture/legacy-force"
if grep -Fq 'Force' "$fixture/legacy-force"; then
    echo 'Legacy force selections must render as unified removal' >&2
    exit 1
fi

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
grep -Fq 'APPLICATION TREE (4 apps)  node 1/8' "$fixture/ascii"
grep -Fq 'e/u/r set node outcome' "$fixture/ascii"
grep -Fq 'left/right collapse/expand' "$fixture/ascii"
if grep -Fq 'left/right lane' "$fixture/ascii"; then
    echo 'Planning tree must not advertise outcome lanes as navigation' >&2
    exit 1
fi

cat >"$fixture/events" <<'EOF'
#!/usr/bin/env bash
event_fd=${DOTFILES_INSTALL_PLAN_EVENT_FD:-1}
printf 'event\t1\trun-start\t2\n' >&"$event_fd"
printf 'diagnostic stdout\n'
printf 'diagnostic stderr\n' >&2
printf 'event\t1\toperation-start\tapp:one\tOne\tindeterminate\n' >&"$event_fd"
printf 'event\t1\toperation-settled\tapp:one\tsucceeded\t1\t2\n' >&"$event_fd"
printf 'event\t1\toperation-start\tstep:links\tLinks\tindeterminate\n' >&"$event_fd"
printf 'event\t1\toperation-settled\tstep:links\tsucceeded\t2\t2\n' >&"$event_fd"
printf 'event\t1\trun-settled\tsucceeded\t2\t2\n' >&"$event_fd"
EOF
chmod +x "$fixture/events"
TERM=xterm "$fixture/dotfiles-tui" run -- "$fixture/events" >"$fixture/run"
grep -Fq '[RUN]' "$fixture/run"
grep -Fq 'Ensure · Leave · Remove' "$fixture/run"
grep -Fq '2/2 settled' "$fixture/run"
grep -Fq 'One — succeeded' "$fixture/run"
grep -Fq 'Run settled successfully' "$fixture/run"
run_log="$fixture/state/dotfiles/latest-run.log"
if stat -c '%a' "$run_log" >/dev/null 2>&1; then
    log_mode=$(stat -c '%a' "$run_log")
else
    log_mode=$(stat -f '%Lp' "$run_log")
fi
[[ -f "$run_log" && "$log_mode" == 600 ]]
grep -Fq "$run_log" "$fixture/run"
grep -Fq $'\tevent\tevent\t1\trun-start\t2' "$run_log"
grep -Fq $'\tstdout\tdiagnostic stdout' "$run_log"
grep -Fq $'\tstderr\tdiagnostic stderr' "$run_log"
grep -Fq $'\tfinish\tsucceeded' "$run_log"

cat >"$fixture/interrupt-events" <<'EOF'
#!/usr/bin/env bash
event_fd=${DOTFILES_INSTALL_PLAN_EVENT_FD:-1}
trap 'printf "engine received interrupt\n" >&2; exit 130' INT TERM
printf 'event\t1\trun-start\t1\n' >&"$event_fd"
printf 'event\t1\toperation-start\tapp:wait\tWait\tindeterminate\n' >&"$event_fd"
printf 'ready\n' >"$INTERRUPT_READY"
while :; do sleep 1; done
EOF
chmod +x "$fixture/interrupt-events"
rm -f "$run_log"
mkfifo "$fixture/interrupt-ready"
INTERRUPT_READY="$fixture/interrupt-ready" TERM=xterm "$fixture/dotfiles-tui" run -- "$fixture/interrupt-events" >"$fixture/interrupt-run" 2>&1 &
interrupt_pid=$!
read -r interrupt_ready <"$fixture/interrupt-ready"
[[ "$interrupt_ready" == ready ]]
kill -TERM "$interrupt_pid"
if wait "$interrupt_pid"; then
    echo 'Expected interrupted progress command to fail' >&2
    exit 1
fi
grep -Fq $'\tstderr\tengine received interrupt' "$run_log"
grep -Fq $'\tfinish\tfailed:' "$run_log"

cat >"$fixture/failing-command" <<'EOF'
#!/usr/bin/env bash
event_fd=${DOTFILES_INSTALL_PLAN_EVENT_FD:-1}
printf 'event\t1\trun-start\t1\n' >&"$event_fd"
printf 'adapter failed clearly\n' >&2
exit 17
EOF
chmod +x "$fixture/failing-command"
if TERM=xterm "$fixture/dotfiles-tui" run -- "$fixture/failing-command" >"$fixture/failing-run" 2>&1; then
    echo 'Expected adapter exit status to fail the run' >&2
    exit 1
fi
grep -Fq 'exit status 17' "$fixture/failing-run"
grep -Fq $'\tstderr\tadapter failed clearly' "$run_log"
grep -Fq $'\tfinish\tfailed: exit status 17' "$run_log"

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

printf 'Planning-tree TUI and progress rendering tests passed.\n'
