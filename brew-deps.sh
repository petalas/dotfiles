#!/usr/bin/env bash
set -e

if [[ ! $OSTYPE == "darwin"* ]]; then
	echo "Not MacOS, exiting."
	exit 1
fi

red=$(tput setaf 1 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
declare -a warnings=()

# shellcheck source=lib/homebrew.sh disable=SC1091
source "$(dirname "$0")/lib/homebrew.sh"

warn_failure() {
	local label="$1"
	warnings+=("$label")
	printf '%sWarning: %s failed; continuing with independent steps.%s\n' "$yellow" "$label" "$reset" >&2
}

run_optional() {
	local label="$1"
	shift
	if "$@"; then
		return 0
	fi
	warn_failure "$label"
	return 1
}

skip_dependent() {
	local label="$1"
	warnings+=("$label (prerequisite unavailable)")
	printf '%sSkipping %s because its prerequisite failed.%s\n' "$yellow" "$label" "$reset" >&2
}

# Check if Homebrew is installed
if ! ./setup-brew.sh; then
	echo "${red}Homebrew setup failed; cannot install macOS dependencies.${reset}" >&2
	exit 1
fi

if ! command -v brew &>/dev/null; then
	echo "${red}Failed to install homebrew${reset}, check ${yellow}setup-brew.sh${reset}"
	exit 1
fi

## not managed by homebrew, have to create .nvm dir manually on first install
if [ ! -d "$HOME/.nvm" ]; then
	echo "Creating nvm dir: $HOME/.nvm"
	mkdir "$HOME/.nvm"
fi

printf "\nUpdating Homebrew...\n"
run_optional "Homebrew metadata update" brew update || true

# jq is consumed by the required dotfile-linking stage. Node's nvm and
# SDKMAN's modern Bash only gate their own optional branches, which handle
# missing prerequisites below without aborting unrelated work.
required_formulae=(jq)
for formula in "${required_formulae[@]}"; do
	if brew list --versions "$formula" >/dev/null 2>&1; then
		continue
	fi
	if ! brew install "$formula"; then
		printf '%sRequired Homebrew formula %s failed to install; cannot continue.%s\n' \
			"$red" "$formula" "$reset" >&2
		exit 1
	fi
done

# Translate user-facing SKIP_* env vars to HOMEBREW_SKIP_* so the Brewfile
# can see them. Homebrew strips non-HOMEBREW_ env vars before Brewfile eval.
for g in CAD GAMING MOBILE; do
	var="SKIP_$g"
	if [[ -n "${!var}" ]]; then
		export "HOMEBREW_SKIP_$g=1"
	fi
done

# Install everything declared in Brewfile.
# Per-machine subsetting: SKIP_CAD=1 SKIP_GAMING=1 SKIP_MOBILE=1 ./brew-deps.sh
# Drift check: brew bundle cleanup --file=Brewfile
brewfile="$(dirname "$0")/Brewfile"
run_optional "Brewfile dependencies" homebrew_bundle_install_resilient "$brewfile" || true
run_optional "Homebrew package upgrades" homebrew_upgrade_individually || true

# source installers for non-Brewfile deps and macOS Neovim HEAD conversion
# shellcheck source=installers/source_installers.sh disable=SC1091
source "$(dirname "$0")/installers/source_installers.sh"

# Ghostty is declared in Brewfile, but the installer also makes it the default
# terminal through LaunchServices. It is safe to rerun when already installed.
run_optional "Ghostty default terminal" install_ghostty || true

# Neovim is declared in Brewfile with HEAD, but brew bundle will not convert an
# already-installed stable formula to HEAD. The installer handles that case.
run_optional "Neovim" install_neovim || true
if run_optional "Node runtime" install_node; then
	if command -v npm >/dev/null 2>&1; then
		run_optional "global Node packages" install_node_deps || true
	else
		skip_dependent "global Node packages"
	fi
else
	skip_dependent "global Node packages"
fi
run_optional "Bun" install_bun || true
if run_optional "SDKMAN" install_sdkman; then
	# install_sdkman_deps keeps SDKMAN inside a Bash 4+ subprocess when this
	# orchestration script is running under Apple's Bash 3.
	run_optional "SDKMAN packages" install_sdkman_deps || true
else
	skip_dependent "SDKMAN packages"
fi
if run_optional "Rust toolchain" install_rust; then
	if command -v cargo >/dev/null 2>&1; then
		run_optional "Rust packages" install_rust_deps || true
		run_optional "Yazi" install_yazi || true
	else
		skip_dependent "Rust packages"
		skip_dependent "Yazi"
	fi
else
	skip_dependent "Rust packages"
	skip_dependent "Yazi"
fi

if ((${#warnings[@]} > 0)); then
	printf '\n%sSetup completed with %d warning(s):%s\n' "$yellow" "${#warnings[@]}" "$reset" >&2
	for warning in "${warnings[@]}"; do
		printf '  - %s\n' "$warning" >&2
	done
fi
