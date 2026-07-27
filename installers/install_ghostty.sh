#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh

_detect_os_for_ghostty() {
	if [[ "$OSTYPE" == darwin* ]]; then
		os_id="macos"
		return 0
	fi
	if [[ -f /etc/os-release ]]; then
		os_id=$(grep -w ID /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
		[[ "$os_id" == "archarm" ]] && os_id="arch"
		return 0
	fi
	os_id=""
}

set_ghostty_default_terminal_macos() {
	local app_path="${GHOSTTY_APP_PATH:-}"
	local candidate swift_bin

	if [[ -z "$app_path" ]]; then
		for candidate in /Applications/Ghostty.app "$HOME/Applications/Ghostty.app"; do
			if [[ -d "$candidate" ]]; then
				app_path="$candidate"
				break
			fi
		done
	fi
	if [[ -z "$app_path" || ! -d "$app_path" ]]; then
		echo "Ghostty.app not found; cannot set the macOS default terminal." >&2
		return 1
	fi

	# Ghostty's own “Make Ghostty the Default Terminal” menu item uses this
	# NSWorkspace API. Invoke it directly so fresh-machine setup stays
	# non-interactive and avoids an additional duti dependency.
	swift_bin=$(xcrun --find swift 2>/dev/null || command -v swift 2>/dev/null || true)
	if [[ -z "$swift_bin" ]]; then
		echo "Swift is unavailable; cannot set the macOS default terminal." >&2
		return 1
	fi

	if ! "$swift_bin" - "$app_path" <<'SWIFT'
import AppKit
import UniformTypeIdentifiers

let appURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let contentTypes: [UTType] = [
    .unixExecutable,
    .shellScript,
    UTType(importedAs: "com.apple.terminal.shell-script")
]

func defaultApplication(for contentType: UTType) -> URL? {
    LSCopyDefaultApplicationURLForContentType(
        contentType.identifier as CFString,
        .all,
        nil
    )?.takeRetainedValue() as URL?
}

for contentType in contentTypes {
    if defaultApplication(for: contentType)?.standardizedFileURL == appURL {
        continue
    }

    let semaphore = DispatchSemaphore(value: 0)
    var setError: Error?
    NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: contentType) { error in
        setError = error
        semaphore.signal()
    }
    semaphore.wait()

    if let setError = setError {
        FileHandle.standardError.write(Data(
            "Failed to associate \(contentType.identifier) with Ghostty: \(setError.localizedDescription)\n".utf8
        ))
        exit(1)
    }

    if defaultApplication(for: contentType)?.standardizedFileURL != appURL {
        FileHandle.standardError.write(Data(
            "macOS did not retain Ghostty for \(contentType.identifier)\n".utf8
        ))
        exit(1)
    }
}
SWIFT
	then
		return 1
	fi

	echo "${green:-}Ghostty${reset:-} is the macOS default terminal."
}

set_ghostty_default_terminal_linux() {
	local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
	local data_dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
	local data_dir desktop_name

	mkdir -p "$config_home"
	while IFS= read -r data_dir; do
		for desktop_name in com.mitchellh.ghostty.desktop ghostty.desktop; do
			if [[ -f "$data_dir/applications/$desktop_name" ]]; then
				printf '%s\n' "$desktop_name" >"$config_home/xdg-terminals.list"
				return 0
			fi
		done
	done < <(printf '%s' "$data_dirs" | tr ':' '\n')

	# Ghostty's Linux app ID is com.mitchellh.ghostty; write the expected
	# desktop entry name even if the package manager installed it elsewhere.
	printf '%s\n' 'com.mitchellh.ghostty.desktop' >"$config_home/xdg-terminals.list"
}

set_ghostty_default_terminal() {
	case "${os_id:-}" in
		macos) set_ghostty_default_terminal_macos ;;
		arch | ubuntu | debian) set_ghostty_default_terminal_linux ;;
	esac
}

install_ghostty() {
	if [[ -z "${os_id:-}" ]]; then
		_detect_os_for_ghostty
	fi

	if command -v ghostty >/dev/null 2>&1; then
		echo "${green:-}ghostty${reset:-} is already installed."
		set_ghostty_default_terminal
		return
	fi
	if [[ "$os_id" == "macos" ]] && command -v brew >/dev/null 2>&1 && brew list --cask ghostty >/dev/null 2>&1; then
		echo "${green:-}ghostty${reset:-} is already installed."
		set_ghostty_default_terminal
		return
	fi

	if [[ "$os_id" == "macos" ]]; then
		echo "Installing ${yellow:-}ghostty${reset:-} ..."
		brew install --cask ghostty || return 1
		set_ghostty_default_terminal
	elif [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
		echo "Installing ${yellow:-}ghostty${reset:-} ..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)" || return 1
		set_ghostty_default_terminal
	elif [[ "$os_id" == "arch" ]]; then
		echo "Installing ${yellow:-}ghostty${reset:-} ..."
		paru -S --noconfirm --needed ghostty || return 1
		set_ghostty_default_terminal
	else
		echo "Unsupported OS: $os_id"
		return 1
	fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	install_ghostty
fi
