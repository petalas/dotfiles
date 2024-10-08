#!/bin/bash

# zshrc
[ -e $HOME/.zshrc.old ] && rm $HOME/.zshrc.old
if [ -e $HOME/.zshrc ]; then
    echo "Creating backup: $HOME/.zshrc.old"
    cp $HOME/.zshrc $HOME/.zshrc.old
    rm $HOME/.zshrc
fi
echo "Linking $(pwd)/dot/zshrc -> $HOME/.zshrc"
ln -s "$(pwd)/dot/zshrc" $HOME/.zshrc

# gitconfig
[ -e $HOME/.gitconfig.old ] && rm $HOME/.gitconfig.old
if [ -e $HOME/.gitconfig ]; then
    echo "Creating backup: $HOME/.gitconfig.old"
    cp $HOME/.gitconfig $HOME/.gitconfig.old
    rm $HOME/.gitconfig
fi
echo "Linking $(pwd)/dot/gitconfig -> $HOME/.gitconfig"
ln -s "$(pwd)/dot/gitconfig" $HOME/.gitconfig

# ensure $HOME/.config exists
if [ ! -d "$HOME/.config" ]; then
    echo "Creating: $HOME/.config"
    mkdir -p $HOME/.config
fi

# alacritty
[ -d $HOME/.config/alacritty.old ] && rm -rf $HOME/.config/alacritty.old
if [ -d $HOME/.config/alacritty ]; then
    echo "Creating backup: $HOME/.config/alacritty.old"
    cp -r $HOME/.config/alacritty $HOME/.config/alacritty.old
    rm -rf $HOME/.config/alacritty
fi
mkdir $HOME/.config/alacritty
ln -s "$(pwd)/dot/.config/alacritty/catppuccin-mocha.yml" $HOME/.config/alacritty/catppuccin-mocha.yml
if [[ $OSTYPE == "darwin"* ]]; then
    echo "Linking $(pwd)/dot/.config/alacritty/alacritty-mac.yml -> $HOME/.config/alacritty/alacritty.yml"
    ln -s "$(pwd)/dot/.config/alacritty/alacritty-mac.yml" $HOME/.config/alacritty/alacritty.yml
else
    echo "Linking $(pwd)/dot/.config/alacritty/alacritty.yml -> $HOME/.config/alacritty/alacritty.yml"
    ln -s "$(pwd)/dot/.config/alacritty/alacritty.yml" $HOME/.config/alacritty/alacritty.yml
fi

# kitty
[ -d $HOME/.config/kitty.old ] && rm -rf $HOME/.config/kitty.old
if [ -d $HOME/.config/kitty ]; then
    echo "Creating backup: $HOME/.config/kitty.old"
    cp -r $HOME/.config/kitty $HOME/.config/kitty.old
    rm -rf $HOME/.config/kitty
fi
mkdir $HOME/.config/kitty
echo "Linking $(pwd)/dot/.config/kitty/kitty.conf -> $HOME/.config/kitty/kitty.conf"
ln -s "$(pwd)/dot/.config/kitty/kitty.conf" $HOME/.config/kitty/kitty.conf

# nvim
# create backup and nuke old config
[ -d $HOME/.config/nvim.old ] && rm -rf $HOME/.config/nvim.old
if [ -d $HOME/.config/nvim ]; then
    echo "Creating backup: $HOME/.config/nvim.old"
    cp -r $HOME/.config/nvim $HOME/.config/nvim.old
    rm -rf $HOME/.config/nvim

    # "resetting neovim cache, plugins, data"
    rm -rf $HOME/.cache/nvim $HOME/.config/nvim/plugin $HOME/.local/share/nvim $HOME/.config/nvim/plugin
fi

git clone https://github.com/petalas/nvim.git $HOME/.config/nvim -b custom

# make sure $HOME/git/genesis exists before linking
if [ ! -d "$HOME/git/genesis" ]; then
    echo "Creating: $HOME/git/genesis"
    mkdir -p $HOME/git/genesis
fi

[ -e $HOME/git/genesis/.gitconfig.old ] && rm $HOME/git/genesis/.gitconfig.old
if [ -e $HOME/git/genesis/.gitconfig ]; then
    echo "Creating backup: $HOME/.gitconfig.old"
    cp $HOME/git/genesis/.gitconfig $HOME/git/genesis/.gitconfig.old
    rm $HOME/git/genesis/.gitconfig
fi

echo "Linking $(pwd)/dot/genesis/gitconfig -> $HOME/git/genesis/.gitconfig"
ln -s "$(pwd)/dot/genesis/gitconfig" $HOME/git/genesis/.gitconfig
