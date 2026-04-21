#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_neovim() {
    if command -v nvim >/dev/null 2>&1; then
        return 0
    fi


    if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
        echo "Installing ${yellow}nvim${reset} ..."
        curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz -o /tmp/nvim-linux-x86_64.tar.gz
        sudo rm -rf /opt/nvim
        sudo tar -C /opt -xzf /tmp/nvim-linux-x86_64.tar.gz
        sudo mv /opt/nvim-linux-x86_64 /opt/nvim
    elif [[ "$os_id" == "arch" ]]; then
        echo "Installing ${yellow}nvim${reset} ..."
        paru -S --noconfirm --needed neovim
    else
        echo "Unsupported OS: $os_id"
        return 1
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_neovim
fi 
