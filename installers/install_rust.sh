#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id provided by source_installers.sh


install_rust() {
    if ! command -v rustc || ! command -v cargo >/dev/null 2>&1 || ! command -v rustup >/dev/null 2>&1; then
        if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" || "$os_id" == "macos" ]]; then
            echo
            echo ":: ${green}Installing rust...${reset}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || return 1
            source "$HOME/.cargo/env"
        elif [[ "$os_id" == "arch" ]]; then
            sudo pacman -Sy --noconfirm rustup
            rustup default stable
        fi
        rustup component add rust-analyzer
        rustup component add rustfmt
    else
        echo ":: ${yellow}rust${reset} is ${green}already installed${reset}."
    fi
}

# Call the function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust
fi 
