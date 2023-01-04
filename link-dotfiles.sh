#!/bin/bash

echo "Linking $(pwd)/dot/zshrc -> $HOME/.zshrc (you might be prompted to delete existing dotfile)"
[ -f $HOME/.zshrc ] && rm -i $HOME/.zshrc
ln -s "$(pwd)/dot/zshrc" $HOME/.zshrc

echo "Linking $(pwd)/dot/gitconfig -> $HOME/.gitconfig (you might be prompted to delete existing dotfile)"
[ -f $HOME/.gitconfig ] && rm -i $HOME/.gitconfig
ln -s "$(pwd)/dot/gitconfig" $HOME/.gitconfig

echo "Linking $(pwd)/dot/genesis/gitconfig -> $HOME/git/genesis/.gitconfig (you might be prompted to delete existing dotfile)"
[ -f $HOME/git/genesis/.gitconfig ] && rm -i $HOME/git/genesis/.gitconfig

# make sure $HOME/git/genesis exists before linking
if [ ! -d "$HOME/git/genesis" ]; then
    echo "Creating: $HOME/git/genesis"
    mkdir $HOME/git/genesis
fi
ln -s "$(pwd)/dot/genesis/gitconfig" $HOME/git/genesis/.gitconfig