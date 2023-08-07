#!/bin/bash
# Just to avoid asking for password multiple times but still run as the current user.
sudo -u $(whoami) ./setup-deps.sh
sudo -u $(whoami) ./setup-fonts.sh
sudo -u $(whoami) ./link-dotfiles.sh
sudo -u $(whoami) ./setup-zsh.sh
