#!/bin/bash
# Just to avoid asking for password multiple times but still run as the current user.
sudo -u $(whoami) ./setup-deps.sh
sudo -u $(whoami) ./setup-fonts.sh
sudo -u $(whoami) ./setup-zsh.sh
sudo -u $(whoami) ./link-dotfiles.sh

echo "Please log out and open an alacritty terminal when you log back in."
echo "The configuration wizard for p10k should run by itself, if not run `p10k configure`"
