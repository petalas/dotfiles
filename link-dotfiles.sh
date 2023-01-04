#!/bin/bash

echo "Linking $(pwd)/dot/zshrc -> $HOME/.zshrc"
[ -f $HOME/.zshrc.old ] && rm $HOME/.zshrc.old
[ -f $HOME/.zshrc ] && echo "Creating backup: $HOME/.zshrc.old" && mv $HOME/.zshrc $HOME/.zshrc.old
ln -s "$(pwd)/dot/zshrc" $HOME/.zshrc

echo "Linking $(pwd)/dot/gitconfig -> $HOME/.gitconfig"
[ -f $HOME/.gitconfig.old ] && rm $HOME/.gitconfig.old
[ -f $HOME/.gitconfig ] && echo "Creating backup: $HOME/.gitconfig.old" && mv $HOME/.gitconfig $HOME/.gitconfig.old
ln -s "$(pwd)/dot/gitconfig" $HOME/.gitconfig

# make sure $HOME/git/genesis exists before linking
if [ ! -d "$HOME/git/genesis" ]; then
    echo "Creating: $HOME/git/genesis"
    mkdir -p $HOME/git/genesis
fi

echo "Linking $(pwd)/dot/genesis/gitconfig -> $HOME/git/genesis/.gitconfig (you might be prompted to delete existing dotfile)"
[ -f $HOME/git/genesis/.gitconfig.old ] && rm $HOME/git/genesis/.gitconfig.old
[ -f $HOME/git/genesis/.gitconfig ] && echo "Creating backup: $HOME/.gitconfig.old" && mv $HOME/git/genesis/.gitconfig $HOME/git/genesis/.gitconfig.old
ln -s "$(pwd)/dot/genesis/gitconfig" $HOME/git/genesis/.gitconfig