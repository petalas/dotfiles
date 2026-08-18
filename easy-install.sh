#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./easy-install.sh [--unattended | --plan FILE]

With no arguments, open the visual installation-plan selector.
  --unattended  Select all available steps and applications.
  --plan FILE   Replay a saved plan without prompting.
EOF
}

mode=visual
record=
case "$#" in
    0) ;;
    1)
        case "$1" in
            --unattended) mode=full ;;
            --help|-h) usage; exit 0 ;;
            *) usage >&2; exit 2 ;;
        esac
        ;;
    2)
        [[ "$1" == --plan ]] || { usage >&2; exit 2; }
        mode=record
        record=$2
        ;;
    *) usage >&2; exit 2 ;;
esac

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$root_dir"
# shellcheck source=lib/platform.sh
source lib/platform.sh

if ! os=$(dotfiles_os); then
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
fi
if [[ "$os" == macos ]] && ((EUID == 0)); then
    echo "Run macOS setup as the target user, not root; Homebrew refuses root installs." >&2
    exit 1
fi

if [[ "$os" != macos ]]; then
    configure_passwordless_sudo
fi
require_noninteractive_root
for command_name in curl git; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "Required command is missing before setup: $command_name" >&2
        exit 1
    }
done

resolved_plan=$(mktemp "${TMPDIR:-/tmp}/dotfiles-resolved-plan.XXXXXX")
approval=$(mktemp "${TMPDIR:-/tmp}/dotfiles-plan-approval.XXXXXX")
observations=$(mktemp "${TMPDIR:-/tmp}/dotfiles-observations.XXXXXX")
rm -f "$approval"
trap 'rm -f "$resolved_plan" "$approval" "$observations"' EXIT
prepare_args=(prepare --mode "$mode" --os "$os" --output "$resolved_plan")
if [[ "$mode" == visual ]]; then
    "$root_dir/tools/run-install-tui" run -- "$root_dir/lib/install-plan" inspect --os "$os" --output "$observations"
    prepare_args+=(--approval "$approval" --observations "$observations")
fi
if [[ "$mode" == record ]]; then
    prepare_args+=(--record "$record")
fi
"$root_dir/lib/install-plan" "${prepare_args[@]}"

# Crossing the confirmation boundary: all descendants are unattended and have
# no readable stdin. The selector's terminal descriptor has already closed.
export NONINTERACTIVE=1 HOMEBREW_NO_ASK=1 DOTFILES_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a GIT_TERMINAL_PROMPT=0
exec </dev/null

report_dir=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
mkdir -p "$report_dir"
run_report=$report_dir/latest-run-report
execute_args=(execute --operation install --plan "$resolved_plan" --report "$run_report")
if [[ "$mode" == visual ]]; then
    execute_args+=(--approval "$approval")
    "$root_dir/tools/run-install-tui" run -- "$root_dir/lib/install-plan" "${execute_args[@]}"
else
    "$root_dir/lib/install-plan" "${execute_args[@]}"
fi
echo "Setup complete. Log out and back in if the login shell changed."
