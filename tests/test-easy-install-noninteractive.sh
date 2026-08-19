#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d /tmp/dotfiles-easy-install.XXXXXX)
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/bin" "$fixture_dir/home" "$fixture_dir/lib" "$fixture_dir/tools"
cp "$repo_dir/easy-install.sh" "$fixture_dir/easy-install.sh"
cp "$repo_dir/lib/platform.sh" "$fixture_dir/lib/platform.sh"

cat >"$fixture_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_SUDO_LOG"
if [[ "${1:-}" == -n && "${2:-}" == true ]]; then
    [[ -e "$TEST_SUDO_STATE" ]]
    exit
fi
if [[ "${1:-}" == -k ]]; then
    exit
fi
if [[ "${1:-}" == sh && "${2:-}" == -c ]]; then
    [[ "${TEST_SCENARIO:-}" != sudo_denied ]] || exit 1
    [[ "${6:-}" == /etc/sudoers.d/zz-dotfiles-* ]]
    [[ "${7:-}" == /etc/sudoers.d/dotfiles-* ]]
    grep -Eq '^\\#[0-9]+ ALL=\(ALL:ALL\) NOPASSWD: ALL$' "$5"
    cp "$5" "$TEST_SUDOERS_CAPTURE"
    touch "$TEST_SUDO_STATE"
    exit
fi
exit 1
EOF
for command_name in curl git; do
    cat >"$fixture_dir/bin/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
done
cat >"$fixture_dir/bin/systemd-inhibit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_SYSTEMD_INHIBIT_LOG"
if [[ "${1:-}" == --list ]]; then
    [[ "${TEST_SCENARIO:-}" != inhibitors_unavailable ]]
    exit
fi
while [[ "${1:-}" == --* ]]; do shift; done
export TEST_SYSTEMD_INHIBITOR_ACTIVE=1
exec "$@"
EOF
cat >"$fixture_dir/bin/gnome-session-inhibit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_GNOME_INHIBIT_LOG"
if [[ "${1:-}" == --list ]]; then
    [[ "${TEST_SCENARIO:-}" != gnome_unavailable &&
        "${TEST_SCENARIO:-}" != inhibitors_unavailable ]]
    exit
fi
# Debian's gnome-session-inhibit parser accepts these options only as separate
# argument/value pairs; --option=value is treated as the child command.
for option in --app-id --reason --inhibit; do
    [[ "${1:-}" == "$option" && -n "${2:-}" ]] || {
        printf 'Failed to execute %s\n' "${1:-}" >&2
        exit 1
    }
    shift 2
done
export TEST_GNOME_INHIBITOR_ACTIVE=1
exec "$@"
EOF
cat >"$fixture_dir/bin/getent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == passwd ]]; then
    printf '%s:x:1000:1000::%s:%s\n' "$2" "$HOME" "${TEST_LOGIN_SHELL:-/bin/bash}"
    exit 0
fi
exec /usr/bin/getent "$@"
EOF
cat >"$fixture_dir/bin/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$fixture_dir/bin/ghostty" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${TEST_SYSTEMD_INHIBITOR_ACTIVE:-0}" == 0 ]]
[[ "${TEST_GNOME_INHIBITOR_ACTIVE:-0}" == 0 ]]
printf 'SHELL=%s args=%s\n' "${SHELL:-}" "$*" >"$TEST_GHOSTTY_LAUNCH"
EOF
cat >"$fixture_dir/lib/install-plan" <<'EOF'
#!/usr/bin/env bash
command=$1
shift
printf '%s %s\n' "$command" "$*" >>"$TEST_STEPS"
case "$command" in
    inspect)
        while (($#)); do
            if [[ "$1" == --output ]]; then printf 'format\t1\nos\tmacos\n' >"$2"; break; fi
            shift
        done
        ;;
    prepare)
        [[ "${NONINTERACTIVE:-0}" == 0 ]]
        [[ "${TEST_SCENARIO:-}" != prepare_failure ]] || exit 1
        while (($#)); do
            if [[ "$1" == --output ]]; then printf 'plan\n' >"$2"; break; fi
            shift
        done
        ;;
    execute|apply)
        [[ "${NONINTERACTIVE:-}" == 1 ]]
        [[ "${DOTFILES_NONINTERACTIVE:-}" == 1 ]]
        if [[ "${TEST_SCENARIO:-}" != inhibitors_unavailable ]]; then
            [[ "${TEST_SYSTEMD_INHIBITOR_ACTIVE:-}" == 1 ]]
        fi
        if [[ "${TEST_SCENARIO:-}" != gnome_unavailable &&
            "${TEST_SCENARIO:-}" != inhibitors_unavailable ]]; then
            [[ "${TEST_GNOME_INHIBITOR_ACTIVE:-}" == 1 ]]
        fi
        if IFS= read -r _; then echo 'apply stdin was open' >&2; exit 1; fi
        [[ "${TEST_SCENARIO:-}" != apply_failure ]]
        ;;
esac
EOF
cat >"$fixture_dir/tools/run-install-tui" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == run && "$2" == -- ]]; then shift 2; exec "$@"; fi
exit 1
EOF
chmod +x "$fixture_dir/bin"/* "$fixture_dir/lib/install-plan" "$fixture_dir/tools/run-install-tui" "$fixture_dir/easy-install.sh"

steps="$fixture_dir/steps"
run_install() {
    local scenario=$1
    shift
    : >"$steps"
    rm -f "$fixture_dir/$scenario.sudo-ready" "$fixture_dir/$scenario.sudoers"
    : >"$fixture_dir/$scenario.sudo.log"
    : >"$fixture_dir/$scenario.systemd-inhibit.log"
    : >"$fixture_dir/$scenario.gnome-inhibit.log"
    env TEST_SCENARIO="$scenario" TEST_STEPS="$steps" \
        TEST_SUDO_LOG="$fixture_dir/$scenario.sudo.log" \
        TEST_SUDO_STATE="$fixture_dir/$scenario.sudo-ready" \
        TEST_SUDOERS_CAPTURE="$fixture_dir/$scenario.sudoers" \
        TEST_SYSTEMD_INHIBIT_LOG="$fixture_dir/$scenario.systemd-inhibit.log" \
        TEST_GNOME_INHIBIT_LOG="$fixture_dir/$scenario.gnome-inhibit.log" \
        HOME="$fixture_dir/home" DOTFILES_OS_OVERRIDE=debian \
        XDG_CURRENT_DESKTOP=GNOME DBUS_SESSION_BUS_ADDRESS=fixture \
        PATH="$fixture_dir/bin:/usr/bin:/bin" \
        "${EASY_INSTALL_TEST_ENTRY_BASH:-$BASH}" "$fixture_dir/easy-install.sh" "$@" \
        >"$fixture_dir/$scenario.log" 2>&1
}

run_install visual
[[ "$(sed -n '1p' "$steps")" == inspect*'--os '* ]]
[[ "$(sed -n '2p' "$steps")" == prepare*'--mode visual'* ]]
[[ "$(sed -n '3p' "$steps")" == execute*'--operation install'* ]]
grep -Fq -- '--what=idle:sleep --mode=block' "$fixture_dir/visual.systemd-inhibit.log"
grep -Fq -- '--app-id dotfiles-installer --reason Machine setup is running --inhibit idle:suspend' \
    "$fixture_dir/visual.gnome-inhibit.log"

run_install gnome_unavailable --unattended
grep -Fq -- '--what=idle:sleep --mode=block' "$fixture_dir/gnome_unavailable.systemd-inhibit.log"
[[ "$(wc -l <"$fixture_dir/gnome_unavailable.gnome-inhibit.log")" == 1 ]]

run_install inhibitors_unavailable --unattended
[[ "$(wc -l <"$fixture_dir/inhibitors_unavailable.systemd-inhibit.log")" == 1 ]]
[[ "$(wc -l <"$fixture_dir/inhibitors_unavailable.gnome-inhibit.log")" == 1 ]]

run_install unattended --unattended
grep -Fq 'prepare --mode full' "$steps"
[[ -s "$fixture_dir/unattended.sudoers" ]]
[[ "$(grep -c '^sh -c ' "$fixture_dir/unattended.sudo.log")" == 1 ]]
grep -Fxq -- '-k' "$fixture_dir/unattended.sudo.log"
grep -Fxq -- '-n true' "$fixture_dir/unattended.sudo.log"

plan="$fixture_dir/custom-plan"
printf 'format=1\n' >"$plan"
run_install replay --plan "$plan"
grep -Fq 'prepare --mode record' "$steps"
grep -Fq -- "--record $plan" "$steps"

if run_install unknown --wat; then
    echo 'Expected unknown option to fail' >&2
    exit 1
fi
[[ ! -s "$steps" ]]

if run_install apply_failure --unattended; then
    echo 'Expected apply failure to propagate' >&2
    exit 1
fi
if run_install prepare_failure --unattended; then
    echo 'Expected prepare failure to stop before apply' >&2
    exit 1
fi
[[ "$(wc -l <"$steps")" == 1 ]]

if run_install sudo_denied --unattended; then
    echo "Expected denied administrator access to stop setup" >&2
    exit 1
fi
[[ ! -s "$steps" ]]
grep -Fq 'Could not configure passwordless sudo' "$fixture_dir/sudo_denied.log"

run_install help --help
grep -Fq 'Usage:' "$fixture_dir/help.log"
[[ ! -s "$steps" ]]
[[ ! -s "$fixture_dir/help.systemd-inhibit.log" ]]
[[ ! -s "$fixture_dir/help.gnome-inhibit.log" ]]

command -v python3 >/dev/null 2>&1 || {
    echo "Python unavailable; Ghostty launch regression skipped."
    echo "easy-install mode contract tests passed."
    exit 0
}
rm -f "$fixture_dir/launch.ghostty" "$fixture_dir/launch.sudo-ready"
: >"$fixture_dir/launch.sudo.log"
: >"$fixture_dir/launch.systemd-inhibit.log"
: >"$fixture_dir/launch.gnome-inhibit.log"
TEST_FIXTURE_DIR="$fixture_dir" TEST_ENTRY_BASH="${EASY_INSTALL_TEST_ENTRY_BASH:-$BASH}" python3 <<'PY'
import os
import pty
import time

fixture = os.environ["TEST_FIXTURE_DIR"]
pid, descriptor = pty.fork()
if pid == 0:
    environment = os.environ.copy()
    environment.update({
        "TEST_SCENARIO": "launch",
        "TEST_STEPS": fixture + "/steps",
        "TEST_SUDO_LOG": fixture + "/launch.sudo.log",
        "TEST_SUDO_STATE": fixture + "/launch.sudo-ready",
        "TEST_SUDOERS_CAPTURE": fixture + "/launch.sudoers",
        "TEST_SYSTEMD_INHIBIT_LOG": fixture + "/launch.systemd-inhibit.log",
        "TEST_GNOME_INHIBIT_LOG": fixture + "/launch.gnome-inhibit.log",
        "TEST_LOGIN_SHELL": fixture + "/bin/zsh",
        "TEST_GHOSTTY_LAUNCH": fixture + "/launch.ghostty",
        "HOME": fixture + "/home",
        "SHELL": "/bin/bash",
        "DOTFILES_OS_OVERRIDE": "debian",
        "XDG_CURRENT_DESKTOP": "GNOME",
        "DBUS_SESSION_BUS_ADDRESS": "fixture",
        "PATH": fixture + "/bin:/usr/bin:/bin",
    })
    shell = os.environ["TEST_ENTRY_BASH"]
    os.execve(shell, [shell, fixture + "/easy-install.sh"], environment)

status = None
deadline = time.time() + 10
while time.time() < deadline:
    finished, child_status = os.waitpid(pid, os.WNOHANG)
    if finished:
        status = child_status
        break
    time.sleep(0.05)
if status is None:
    os.kill(pid, 9)
    raise SystemExit("visual install did not finish after launching Ghostty")
if not os.WIFEXITED(status) or os.WEXITSTATUS(status) != 0:
    raise SystemExit("visual install or Ghostty launch failed")

launch = fixture + "/launch.ghostty"
deadline = time.time() + 2
while time.time() < deadline and not os.path.exists(launch):
    time.sleep(0.05)
if not os.path.exists(launch):
    raise SystemExit("visual install did not launch Ghostty")
PY
grep -Fqx "SHELL=$fixture_dir/bin/zsh args=-e $fixture_dir/bin/zsh -l" \
    "$fixture_dir/launch.ghostty"

echo "easy-install mode contract tests passed."
