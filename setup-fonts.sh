#!/bin/bash

# Set colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

nerdfontsrepo='https://api.github.com/repos/ryanoasis/nerd-fonts'
dist_dir="$HOME/.local/share/fonts"
down_dir="$(command -V xdg-user-dir &>/dev/null && xdg-user-dir DOWNLOAD || echo "$HOME/Downloads")/NerdFonts"
cache_dir="$HOME/.cache/nerdFonts"

# For Macs, need to set a few different things
if [[ "$os" == 'Darwin' ]]; then
	dist_dir="$HOME/Library/Fonts"
	cache_dir="$HOME/Library/Caches/NerdFonts"
fi


[ -d "$dist_dir" ] && echo "${BLUE}Fonts directory exists, good.${RESET}" || (mkdir -p "$dist_dir" && echo "${GREEN}Created the fonts directory.${RESET}")
[ -d "$down_dir" ] && echo "${BLUE}Fonts download directory exists, good.${RESET}" || (mkdir -p "$down_dir" && echo "${GREEN}Created fonts download directory..${RESET}")
[ -d "$cache_dir" ] || mkdir -p "$cache_dir"


function download_font() {
    release=$(curl --silent "$nerdfontsrepo/releases/latest" | awk -F'"' '/tag_name/ {print $4}')
	echo "${BLUE}$1 download started...${RESET}"
	curl -LJO# "https://github.com/ryanoasis/nerd-fonts/releases/download/$release/$1.zip"
	echo "${GREEN}$1 download finished${RESET}"
}

function install_font() {
    echo "${BLUE}$1 instalation started...${RESET}"
    mkdir -p $dist_dir/$1
    # -q = quiet, -qq = quieter, -o = overwrite WITHOUT prompting
	unzip -qqo "$1.zip" -d "$dist_dir/$1"
	echo "${GREEN}$1 installation finished${RESET}"
}

function remove_zip_files() {
	echo "${BLUE}Removing downloaded zip files from $down_dir...${RESET}"
	for font in "${selected_fonts[@]}"; do
		rm $down_dir/$font.zip
	done
	echo "${GREEN}Downloaded zip files removal suceeded!${RESET}"
}

function update_fonts_cache() {
	echo "${BLUE}Updating fc-cache...${RESET}"
	fc-cache -f 2>&1
	echo "${GREEN}fc-cache: update succeeded!${RESET}"
}

function update_fonts_cache() {
	echo "${BLUE}Updating fonts cache...${RESET}"
	fc-cache -f 2>&1
    # echo "${GREEN}fc-cache: update succeeded!${RESET}"
}

declare -a fonts=("Hack" "FantasqueSansMono")

echo "Installing patched nerd fonts..."
for i in "${fonts[@]}"; do
    if [[ $(fc-list | grep "$i" | tail -1) == *"$i"* ]]; then
        echo "${yellow}$i${reset} is ${green}already installed${reset}".
    else
    pushd "$down_dir" > /dev/null
	# remove the old download font if it exsists
    [ -f $down_dir/$i.zip ] && rm $down_dir/$i.zip
	download_font $i
    install_font $i
    # cleanup
    [ -f $down_dir/$i.zip ] && rm $down_dir/$i.zip
	popd > /dev/null
    fi
done

update_fonts_cache
