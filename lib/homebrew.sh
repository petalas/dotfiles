#!/usr/bin/env bash
# Homebrew helpers shared by macOS setup (Bash) and the zsh `upd` function.

_homebrew_contains_line() {
	local expected="$1"
	local values="$2"
	local value
	while IFS= read -r value; do
		[[ "$value" == "$expected" ]] && return 0
	done <<<"$values"
	return 1
}

_homebrew_report_failure() {
	printf 'Warning: %s failed; continuing with other Homebrew entries.\n' "$1" >&2
}

homebrew_bundle_install_resilient() {
	local brewfile="$1"
	local kind entries entry installed command_label
	local installed_taps installed_formulae installed_casks
	local failed=0

	# Reconcile missing entries only. Upgrades are isolated below so one bad
	# download cannot make Homebrew abandon every other outdated package.
	if brew bundle --no-upgrade --file="$brewfile"; then
		return 0
	fi

	printf 'Brewfile reconciliation failed; retrying missing entries individually.\n' >&2
	if ! installed_taps=$(brew tap); then
		_homebrew_report_failure "listing installed Homebrew taps"
		installed_taps=""
		failed=1
	fi
	if ! installed_formulae=$(brew list --formula --full-name); then
		_homebrew_report_failure "listing installed Homebrew formulae"
		installed_formulae=""
		failed=1
	fi
	if ! installed_casks=$(brew list --cask --full-name); then
		_homebrew_report_failure "listing installed Homebrew casks"
		installed_casks=""
		failed=1
	fi

	for kind in tap formula cask; do
		case "$kind" in
			tap) installed="$installed_taps" ;;
			formula) installed="$installed_formulae" ;;
			cask) installed="$installed_casks" ;;
		esac
		if ! entries=$(brew bundle list "--$kind" --file="$brewfile"); then
			_homebrew_report_failure "listing Brewfile $kind entries"
			failed=1
			continue
		fi
		while IFS= read -r entry; do
			[[ -n "$entry" ]] || continue
			_homebrew_contains_line "$entry" "$installed" && continue
			case "$kind" in
				tap)
					command_label="Brewfile tap $entry"
					if ! brew tap "$entry"; then
						_homebrew_report_failure "$command_label"
						failed=1
					fi
					;;
			formula)
					command_label="Brewfile formula $entry"
					if ! brew install "$entry"; then
						_homebrew_report_failure "$command_label"
						failed=1
					fi
					;;
			cask)
					command_label="Brewfile cask $entry"
					if ! brew install --cask "$entry"; then
						_homebrew_report_failure "$command_label"
						failed=1
					fi
					;;
			esac
		done <<<"$entries"
	done

	return "$failed"
}

homebrew_upgrade_individually() {
	local kind entries entry
	local failed=0

	for kind in formula cask; do
		if ! entries=$(brew outdated "--$kind" --quiet); then
			_homebrew_report_failure "listing outdated Homebrew ${kind}s"
			failed=1
			continue
		fi
		while IFS= read -r entry; do
			[[ -n "$entry" ]] || continue
			printf '\nUpgrading Homebrew %s %s...\n' "$kind" "$entry"
			if ! brew upgrade "--$kind" "$entry"; then
				_homebrew_report_failure "Homebrew $kind $entry"
				failed=1
			fi
		done <<<"$entries"
	done

	return "$failed"
}
