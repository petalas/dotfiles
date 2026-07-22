#!/usr/bin/env bash

if [[ "${DOTFILES_INTEGRATION_TEST:-0}" == "1" ]]; then
	echo "Skipping desktop font installation in the container integration profile."
	exit 0
fi

# Set colors
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
BLUE=$(tput setaf 4 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)

nerdfontsrepo='https://api.github.com/repos/ryanoasis/nerd-fonts'
dist_dir="$HOME/.local/share/fonts"
down_dir="$(command -V xdg-user-dir &>/dev/null && xdg-user-dir DOWNLOAD || echo "$HOME/Downloads")/NerdFonts"
cache_dir="$HOME/.cache/nerdFonts"

# For Macs, need to set a few different things
if [[ $OSTYPE == "darwin"* ]]; then
	dist_dir="$HOME/Library/Fonts"
	cache_dir="$HOME/Library/Caches/NerdFonts"
fi

if [[ -d "$dist_dir" ]]; then
	echo "${BLUE}Fonts directory exists, good.${RESET}"
else
	mkdir -p "$dist_dir" && echo "${GREEN}Created the fonts directory.${RESET}"
fi

if [[ -d "$down_dir" ]]; then
	echo "${BLUE}Fonts download directory exists, good.${RESET}"
else
	mkdir -p "$down_dir" && echo "${GREEN}Created fonts download directory..${RESET}"
fi
[ -d "$cache_dir" ] || mkdir -p "$cache_dir"

function download_font() {
	local font="$1"
	local archive="$font.zip"
	local url="https://github.com/ryanoasis/nerd-fonts/releases/download/$release/$archive"

	echo "${BLUE}$font download started...${RESET}"
	if ! curl --fail --location --show-error --progress-bar --output "$archive" "$url"; then
		echo "${RED}$font download failed: $url${RESET}" >&2
		return 1
	fi

	if ! unzip -tq "$archive" >/dev/null; then
		echo "${RED}$font download is not a valid zip archive.${RESET}" >&2
		return 1
	fi

	echo "${GREEN}$font download finished${RESET}"
}

function install_font() {
	local font="$1"

	echo "${BLUE}$font installation started...${RESET}"
	mkdir -p "$dist_dir/$font"
	# -q = quiet, -qq = quieter, -o = overwrite WITHOUT prompting
	if ! unzip -qqo "$font.zip" -d "$dist_dir/$font"; then
		echo "${RED}$font installation failed.${RESET}" >&2
		return 1
	fi
	echo "${GREEN}$font installation finished${RESET}"
}

function update_fonts_cache() {
	echo "${BLUE}Updating fonts cache...${RESET}"
	if ! fc-cache -f 2>&1; then
		echo "${RED}fc-cache: update failed.${RESET}" >&2
		return 1
	fi
	echo "${GREEN}fc-cache: update succeeded!${RESET}"
}

function is_wsl() {
	grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null
}

function copy_fonts_to_windows() {
	# Get Windows user home directory via wslpath
	win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
	win_fonts_dir=$(wslpath "C:/Users/$win_user/AppData/Local/Microsoft/Windows/Fonts" 2>/dev/null)

	if [[ -z "$win_fonts_dir" || ! -d "$(dirname "$win_fonts_dir")" ]]; then
		echo "${RED}Could not determine Windows fonts directory${RESET}"
		return 1
	fi

	mkdir -p "$win_fonts_dir" 2>/dev/null

	echo "${BLUE}Copying fonts to Windows host at $win_fonts_dir...${RESET}"
	for font in "${fonts[@]}"; do
		if [[ -d "$dist_dir/$font" ]]; then
			cp -r "$dist_dir/$font"/* "$win_fonts_dir/" 2>/dev/null
		fi
	done
	echo "${GREEN}Fonts copied to Windows host!${RESET}"
	echo "${BLUE}Note: You may need to manually install the fonts on Windows by selecting them in $win_fonts_dir and right-clicking -> Install${RESET}"
}

release=$(curl --fail --silent --show-error "$nerdfontsrepo/releases/latest" | awk -F'"' '/tag_name/ {print $4}')
if [[ -z "$release" ]]; then
	echo "${RED}Could not determine latest Nerd Fonts release.${RESET}" >&2
	exit 1
fi

declare -a fonts=("Hack" "FantasqueSansMono" "InconsolataLGC" "Ubuntu" "Iosevka" "IosevkaTerm" "DejaVuSansMono" "FiraCode")
declare -a failed_fonts=()
fonts_installed=false

echo "Installing patched nerd fonts from $release..."
for i in "${fonts[@]}"; do
	if [[ $(fc-list | grep "$i" | tail -1) == *"$i"* ]]; then
		echo "${GREEN}$i${RESET} is already installed."
	else
		pushd "$down_dir" >/dev/null || exit 1
		# remove the old download font if it exists
		[ -f "$down_dir/$i.zip" ] && rm "$down_dir/$i.zip"
		if download_font "$i" && install_font "$i"; then
			fonts_installed=true
		else
			failed_fonts+=("$i")
		fi
		# cleanup
		[ -f "$down_dir/$i.zip" ] && rm "$down_dir/$i.zip"
		popd >/dev/null || exit 1
	fi
done

if $fonts_installed; then
	update_fonts_cache || failed_fonts+=("font-cache")
fi

# If running in WSL, copy fonts to Windows host
if is_wsl; then
	echo "${BLUE}WSL detected, copying fonts to Windows host...${RESET}"
	copy_fonts_to_windows
fi

if ((${#failed_fonts[@]} > 0)); then
	echo "${RED}Failed to install: ${failed_fonts[*]}${RESET}" >&2
	exit 1
fi
