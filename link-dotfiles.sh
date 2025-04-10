#!/usr/bin/env bash

# ensure $HOME/.config exists
if [ ! -d "$HOME/.config" ]; then
    echo "Creating: $HOME/.config"
    mkdir -p $HOME/.config
fi

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

# make sure $HOME/git/work exists before linking
if [ ! -d "$HOME/git/work" ]; then
    echo "Creating: $HOME/git/work"
    mkdir -p $HOME/git/work
fi

[ -e $HOME/git/work/.gitconfig.old ] && rm $HOME/git/work/.gitconfig.old
if [ -e $HOME/git/work/.gitconfig ]; then
    echo "Creating backup: $HOME/git/work/.gitconfig.old"
    cp $HOME/git/work/.gitconfig $HOME/git/work/.gitconfig.old
    rm $HOME/git/work/.gitconfig
fi

echo "Linking $(pwd)/dot/work/gitconfig -> $HOME/git/work/.gitconfig"
ln -s "$(pwd)/dot/work/gitconfig" $HOME/git/work/.gitconfig

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

# yazi
[ -d $HOME/.config/yazi.old ] && rm -rf $HOME/.config/yazi.old
if [ -d $HOME/.config/yazi ]; then
    echo "Creating backup: $HOME/.config/yazi.old"
    cp -r $HOME/.config/yazi $HOME/.config/yazi.old
    rm -rf $HOME/.config/yazi
fi
echo "Linking $(pwd)/dot/.config/yazi -> $HOME/.config/yazi"
ln -s "$(pwd)/dot/.config/yazi" $HOME/.config/yazi
# install plugins
ya pack -a boydaihungst/mediainfo
ya pack -a kirasok/torrent-preview

# bat
[ -d $HOME/.config/bat.old ] && rm -rf $HOME/.config/bat.old
if [ -d $HOME/.config/bat ]; then
    echo "Creating backup: $HOME/.config/bat.old"
    cp -r $HOME/.config/bat $HOME/.config/bat.old
    rm -rf $HOME/.config/bat
fi
echo "Linking $(pwd)/dot/.config/bat -> $HOME/.config/bat"
ln -s "$(pwd)/dot/.config/bat" $HOME/.config/bat
bat cache --build

git clone https://github.com/petalas/nvim.git $HOME/.config/nvim -b custom
