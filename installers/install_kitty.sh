#!/usr/bin/env bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

install_kitty() {
    if [[ $(which kitty) == *"kitty" ]]; then
        return 0
    fi
    
    # Detect OS
    os_id=$(grep -w ID /etc/os-release | cut -d '=' -f 2 | tr -d '"')

    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        echo "Installing ${yellow}kitty${reset} ..."
        curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
        # Create symbolic links to add kitty and kitten to PATH (assuming ~/.local/bin is in
        # your system-wide PATH)
        ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/
        # Place the kitty.desktop file somewhere it can be found by the OS
        cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
        # If you want to open text files and images in kitty via your file manager also add the kitty-open.desktop file
        cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
        # Update the paths to the kitty and its icon in the kitty desktop file(s)
        sed -i "s|Icon=kitty|Icon=$(readlink -f ~)/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
        sed -i "s|Exec=kitty|Exec=$(readlink -f ~)/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
        # Make xdg-terminal-exec (and hence desktop environments that support it use kitty)
        echo 'kitty.desktop' >~/.config/xdg-terminals.list
    elif [[ "$os_id" == "arch" ]]; then
        echo "Installing ${yellow}kitty${reset} ..."
        paru -S --noconfirm --needed kitty
    else
        echo "Unsupported OS: $os_id"
        return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_kitty
fi 