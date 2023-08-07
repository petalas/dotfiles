#!/bin/bash
# Just to avoid asking for password multiple times but still run as the current user.
sudo -u $(whoami) ./setup-deps.sh
sudo -u $(whoami) ./setup-fonts.sh
sudo -u $(whoami) ./setup-zsh.sh
sudo -u $(whoami) ./link-dotfiles.sh

# launch new alacritty terminal,
# nerd font should already be set by linked config file
# run p10k configure if it does not run automatically (it should)
alacritty &
