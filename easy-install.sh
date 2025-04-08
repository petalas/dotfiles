#!/usr/bin/env bash

if [[ $OSTYPE == "msys"* ]]; then
    echo "Cannot install on windows, please install manually."
    exit 1
fi

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

username=$(whoami)
export username

echo "Checking sudo permissions..."
if sudo -n true 2>/dev/null; then
    echo "${green}$username${reset} is already configured as a passwordless sudoer."
else
    echo "Adding ${green}$username${reset} to /etc/sudoers.d/ (passwordless)"
    sudo -E bash -c 'echo "$username ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$username'
fi

echo "${yellow}easy install -> setting up dependencies...${reset}\n"
./setup-deps.sh

echo "${yellow}easy install -> setting up fonts...${reset}\n"
./setup-fonts.sh

echo "${yellow}easy install -> setting up zsh...${reset}\n"
./setup-zsh.sh

echo "${yellow}easy install -> configuring zsh...${reset}\n"
./configure-zsh.sh

echo "${yellow}easy install -> linking dotfiles...${reset}\n"
./link-dotfiles.sh

# source ~/.zshrc
SHELL=$(which zsh) kitty &

printf "\n\nIf this is a fresh installation:\n"
echo "Please ${yellow}log out${reset} (for chsh to take effect) and open a ${green}kitty terminal${reset} when you log back in."
echo "If you want to use a different terminal make sure to set the newly installed nerd font before running p10k configure."
echo "The configuration wizard for p10k should run automatically, if not run: ${green}p10k configure${reset}."
