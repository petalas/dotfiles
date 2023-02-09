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

# nvim
# make sure $HOME/git/genesis exists before linking
if [ ! -d "$HOME/.config" ]; then
    echo "Creating: $HOME/.config"
    mkdir -p $HOME/.config
fi
[ -d $HOME/.config/nvim.old ] && rm -rf $HOME/.config/nvim.old
if [ -d $HOME/.config/nvim ]; then
    echo "Creating backup: $HOME/.config/nvim.old"
    cp -r $HOME/.config/nvim $HOME/.config/nvim.old
    rm -rf $HOME/.config/nvim
fi
echo "Linking $(pwd)/dot/.config/nvim -> $HOME/.config/nvim"
ln -s "$(pwd)/dot/.config/nvim" $HOME/.config/nvim

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