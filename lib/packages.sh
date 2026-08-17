#!/usr/bin/env bash
# Linux package-manager facade shared by Bash setup and the Zsh update command.

if [[ "${_DOTFILES_LINUX_PACKAGES_LOADED:-0}" == 1 ]]; then
    return 0
fi
_DOTFILES_LINUX_PACKAGES_LOADED=1

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _packages_file=${BASH_SOURCE[0]}
else
    _packages_file=$(print -P '%N')
fi
_packages_lib_dir=$(cd "$(dirname "$_packages_file")" && pwd)
# shellcheck source=platform.sh
source "$_packages_lib_dir/platform.sh"
# shellcheck source=download.sh
source "$_packages_lib_dir/download.sh"
# shellcheck source=packages-common.sh
source "$_packages_lib_dir/packages-common.sh"
# shellcheck source=packages-apt.sh
source "$_packages_lib_dir/packages-apt.sh"
# shellcheck source=packages-pacman.sh
source "$_packages_lib_dir/packages-pacman.sh"
# shellcheck source=packages-manager.sh
source "$_packages_lib_dir/packages-manager.sh"
# shellcheck source=packages-mirrors.sh
source "$_packages_lib_dir/packages-mirrors.sh"
unset _packages_file _packages_lib_dir
