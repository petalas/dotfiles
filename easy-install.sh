#!/usr/bin/env bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ $OSTYPE == "msys"* ]]; then
	echo "Cannot install on windows, please install manually."
	exit 1
fi

# Homebrew 6 enables confirmation prompts by default. Keep the whole macOS
# pipeline unattended, including the Homebrew bootstrap and later brew calls
# made by sourced installers.
if [[ $OSTYPE == "darwin"* ]]; then
	export NONINTERACTIVE=1
	export HOMEBREW_NO_ASK=1
fi

red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
declare -a install_warnings=()

run_optional_stage() {
	local label="$1"
	shift
	if "$@"; then
		return 0
	fi
	install_warnings+=("$label")
	printf '%sWarning: %s failed; continuing with independent stages.%s\n' \
		"$yellow" "$label" "$reset" >&2
	return 0
}

# Handles three cases:
#   1. User already has passwordless sudo — no-op
#   2. User has sudo with password — upgrade to NOPASSWD after one prompt
#   3. User has no sudo at all (fresh Arch, custom-created user) — bootstrap
#      via 'su' using the root password, then configure sudoers
ensure_sudo() {
	local user apt_mirror_setup
	user=$(whoami)
	apt_mirror_setup="$(pwd)/setup-apt-mirrors.sh"

	if sudo -n true 2>/dev/null; then
		echo "${green}$user${reset} is already a passwordless sudoer."
		return 0
	fi

	if command -v sudo >/dev/null 2>&1 && sudo -v 2>/dev/null; then
		echo "Upgrading ${green}$user${reset} to passwordless sudo"
		sudo tee "/etc/sudoers.d/$user" >/dev/null <<<"$user ALL=(ALL) NOPASSWD: ALL"
		sudo chmod 0440 "/etc/sudoers.d/$user"
		return 0
	fi

	echo "${yellow}$user${reset} is not in sudoers. Bootstrapping via ${yellow}su${reset} — enter the ROOT password when prompted."

	local script
	script=$(mktemp)
	cat >"$script" <<EOF
#!/bin/sh
set -e
if [ -x '$apt_mirror_setup' ]; then
	'$apt_mirror_setup'
fi
if ! command -v sudo >/dev/null 2>&1; then
	if command -v pacman >/dev/null 2>&1; then
		pacman -Sy --noconfirm sudo
	elif command -v apt-get >/dev/null 2>&1; then
		apt-get update && apt-get install -y sudo
	elif command -v dnf >/dev/null 2>&1; then
		dnf install -y sudo
	else
		echo "No supported package manager; install sudo manually" >&2
		exit 1
	fi
fi
echo '$user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$user
chmod 0440 /etc/sudoers.d/$user
EOF
	chmod +x "$script"

	# Redirect su's stdin from /dev/tty so password prompt reads from the
	# terminal, not whatever the parent bash has (e.g. the curl pipe, which
	# would yield EOF -> 'Authentication token manipulation error').
	if [ -r /dev/tty ] && su -l root -c "sh '$script'" </dev/tty && sudo -n true 2>/dev/null; then
		rm -f "$script"
		echo "${green}✓ sudo configured for $user${reset}"
		return 0
	fi

	# su failed (no root password, locked account, no tty, etc). Leave the
	# helper script on disk so the user has a one-step fix they can run from
	# a root shell.
	local helper="$HOME/dotfiles-grant-sudo.sh"
	mv "$script" "$helper"
	chmod +x "$helper"

	cat <<MSG >&2

${red}Could not bootstrap sudo automatically.${reset}
A helper script was saved to: ${yellow}$helper${reset}

Run ONE of these, then re-run the bootstrap:

  # Open a root shell (password required), run the helper, exit:
  su
  sh $helper
  exit

  # Or, as root directly:
  sh $helper

  # Or the raw one-liner as root:
  echo '$user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$user
  chmod 0440 /etc/sudoers.d/$user

Then:
  curl -fsSL https://raw.githubusercontent.com/petalas/dotfiles/main/bootstrap.sh | bash
MSG
	return 1
}

echo "Checking sudo permissions..."
ensure_sudo

if [[ $OSTYPE == "linux"* ]]; then
	printf '%seasy install -> configuring package mirrors...%s\n\n' "$yellow" "$reset"
	run_optional_stage "package mirror configuration" ./setup-apt-mirrors.sh
fi

printf '%seasy install -> setting up dependencies...%s\n\n' "$yellow" "$reset"
if ! ./setup-deps.sh; then
	echo "${red}Dependency setup failed; cannot continue safely.${reset}" >&2
	exit 1
fi

printf '%seasy install -> setting up fonts...%s\n\n' "$yellow" "$reset"
run_optional_stage "font setup" ./setup-fonts.sh

# Source setup_zsh function
printf '%seasy install -> setting up zsh...%s\n\n' "$yellow" "$reset"
source installers/setup_zsh.sh
run_optional_stage "Zsh setup" setup_zsh

printf '%seasy install -> configuring zsh...%s\n\n' "$yellow" "$reset"
run_optional_stage "Zsh configuration" ./configure-zsh.sh

printf '%seasy install -> linking dotfiles...%s\n\n' "$yellow" "$reset"
if ! ./link-dotfiles.sh; then
	echo "${red}Dotfile linking failed; setup is incomplete.${reset}" >&2
	exit 1
fi

if ((${#install_warnings[@]} > 0)); then
	printf '\n%sSetup completed with %d warning(s):%s\n' \
		"$yellow" "${#install_warnings[@]}" "$reset" >&2
	for warning in "${install_warnings[@]}"; do
		printf '  - %s\n' "$warning" >&2
	done
fi

# Print instructions BEFORE launching Ghostty so user sees them in the current
# terminal. Ghostty is only launched if it's actually on PATH.
printf "\n\nIf this is a fresh installation:\n"
echo "Please ${yellow}log out${reset} (for chsh to take effect) and open a ${green}Ghostty terminal${reset} when you log back in."
echo "If you want to use a different terminal make sure to set the newly installed nerd font before running p10k configure."
echo "The configuration wizard for p10k should run automatically, if not run: ${green}p10k configure${reset}."

if command -v ghostty >/dev/null 2>&1; then
	SHELL=$(which zsh) ghostty &
fi
