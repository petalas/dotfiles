#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
if ! command -v go >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    printf 'Go or Python unavailable; terminal negotiation regression skipped.\n'
    exit 0
fi
fixture=$(mktemp -d /tmp/dotfiles-install-tui-terminal.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
cat >"$fixture/events" <<'EOF'
#!/usr/bin/env bash
event_fd=${DOTFILES_INSTALL_PLAN_EVENT_FD:-1}
printf 'event\t1\trun-start\t1\n' >&"$event_fd"
printf 'event\t1\toperation-start\tapp:one\tOne\tindeterminate\n' >&"$event_fd"
sleep 0.1
printf 'event\t1\toperation-settled\tapp:one\tsucceeded\t1\t1\n' >&"$event_fd"
printf 'event\t1\trun-settled\tsucceeded\t1\t1\n' >&"$event_fd"
EOF
chmod +x "$fixture/events"
go build -o "$fixture/dotfiles-tui" ./cmd/dotfiles-tui
TUI_BINARY="$fixture/dotfiles-tui" EVENT_COMMAND="$fixture/events" python3 <<'PY'
import os
import pty
import select
import time

binary = os.environ["TUI_BINARY"]
events = os.environ["EVENT_COMMAND"]
pid, descriptor = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-ghostty"
    os.environ["TERM_PROGRAM"] = "ghostty"
    os.execv(binary, [binary, "run", "--", events])

output = b""
responses = {
    b"\x1b[?2026$p": b"\x1b[?2026;2$y",
    b"\x1b[?2027$p": b"\x1b[?2027;3$y",
}
answered = set()
deadline = time.time() + 10
while time.time() < deadline:
    readable, _, _ = select.select([descriptor], [], [], 0.1)
    if readable:
        try:
            chunk = os.read(descriptor, 65536)
        except OSError:
            break
        if not chunk:
            break
        output += chunk
        for request, response in responses.items():
            if request in output and request not in answered:
                os.write(descriptor, response)
                answered.add(request)
    finished, status = os.waitpid(pid, os.WNOHANG)
    if finished:
        break
else:
    os.kill(pid, 9)
    raise SystemExit("progress helper did not exit")

# In canonical mode, an unread response is echoed as caret notation. This is
# the exact corruption seen at the prompt after interactive inspection.
for response in (b"^[[?2026;2$y", b"^[[?2027;3$y"):
    if response in output:
        raise SystemExit("terminal capability response leaked into shell output: " + repr(response))
PY
printf 'Progress terminal negotiation regression passed.\n'
