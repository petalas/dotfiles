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
