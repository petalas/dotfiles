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

# ensure ~/.config exists
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

# nvim
[ -d $HOME/.config/nvim.old ] && rm -rf $HOME/.config/nvim.old
if [ -d $HOME/.config/nvim ]; then
    echo "Creating backup: $HOME/.config/nvim.old"
    cp -r $HOME/.config/nvim $HOME/.config/nvim.old
    rm -rf $HOME/.config/nvim
fi

NvChad=1 # clone NvChad and just link custom folder
if [ $NvChad ]; then
    rm -rf $HOME/.config/nvim
    git clone https://github.com/NvChad/NvChad.git $HOME/.config/nvim --depth 1
    echo "Linking $(pwd)/dot/.config/nvim/lua/custom -> $HOME/.config/nvim/lua/custom"
    ln -s "$(pwd)/dot/.config/nvim/lua/custom" $HOME/.config/nvim/lua/custom
else
    echo "Linking $(pwd)/dot/.config/nvim -> $HOME/.config/nvim"
    ln -s "$(pwd)/dot/.config/nvim" $HOME/.config/nvim
fi

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
