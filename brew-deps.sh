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

contains_line() {
	local expected="$1"
	local values="$2"
	local value
	while IFS= read -r value; do
		[[ "$value" == "$expected" ]] && return 0
	done <<<"$values"
	return 1
}

install_brewfile_individually() {
	local brewfile="$1"
	local kind entries entry installed
	local installed_taps installed_formulae installed_casks

	if ! installed_taps=$(brew tap); then
		warn_failure "listing installed Homebrew taps"
		installed_taps=""
	fi
	if ! installed_formulae=$(brew list --formula --full-name); then
		warn_failure "listing installed Homebrew formulae"
		installed_formulae=""
	fi
	if ! installed_casks=$(brew list --cask --full-name); then
		warn_failure "listing installed Homebrew casks"
		installed_casks=""
	fi

	printf '%sRetrying Brewfile entries individually so one failure does not block the rest.%s\n' \
		"$yellow" "$reset" >&2
	for kind in tap formula cask; do
		case "$kind" in
			tap) installed="$installed_taps" ;;
			formula) installed="$installed_formulae" ;;
			cask) installed="$installed_casks" ;;
		esac
		if ! entries=$(brew bundle list "--$kind" --file="$brewfile"); then
			warn_failure "listing Brewfile $kind entries"
			continue
		fi
		while IFS= read -r entry; do
			[[ -n "$entry" ]] || continue
			if contains_line "$entry" "$installed"; then
				continue
			fi
			case "$kind" in
				tap) run_optional "Brewfile tap $entry" brew tap "$entry" || true ;;
				formula) run_optional "Brewfile formula $entry" brew install "$entry" || true ;;
				cask) run_optional "Brewfile cask $entry" brew install --cask "$entry" || true ;;
			esac
		done <<<"$entries"
	done
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
run_optional "Homebrew package upgrade" brew upgrade || true

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
if ! run_optional "Brewfile dependencies" brew bundle --file="$brewfile"; then
	install_brewfile_individually "$brewfile"
fi

# source installers for non-Brewfile deps and macOS Neovim HEAD conversion
# shellcheck source=installers/source_installers.sh disable=SC1091
source "$(dirname "$0")/installers/source_installers.sh"

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
	if type sdk >/dev/null 2>&1; then
		run_optional "SDKMAN packages" install_sdkman_deps || true
	else
		skip_dependent "SDKMAN packages"
	fi
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
