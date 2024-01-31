#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

# Just to avoid asking for password multiple times but still run as the current user.
echo "${yellow}easy install -> setting up dependencies${reset}\n"
sudo -u $(whoami) ./setup-deps.sh

echo "${yellow}easy install -> setting up fonts${reset}\n"
sudo -u $(whoami) ./setup-fonts.sh

echo "${yellow}easy install -> linking dotfiles${reset}\n"
sudo -u $(whoami) ./link-dotfiles.sh

echo "${yellow}easy install -> setting up zsh${reset}\n"
sudo -u $(whoami) ./setup-zsh.sh

echo "${yellow}easy install -> configuring zsh${reset}\n"
sudo -u $(whoami) ./configure-zsh.sh

source ~/.zshrc

printf "\n\nIf this is a fresh installation:\n"
echo "Please ${yellow}log out${reset} (for chsh to take effect) and open an ${green}alacritty terminal${reset} when you log back in."
echo "If you want to use a different terminal make sure to set the newly installed nerd font before running p10k configure."
echo "The configuration wizard for p10k should run automatically, if not run: ${green}p10k configure${reset}."
