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

# ssh
if [ ! -d "$HOME/.ssh" ]; then
    echo "Creating: $HOME/.ssh"
    mkdir -p $HOME/.ssh
    chmod 700 $HOME/.ssh
fi

[ -e $HOME/.ssh/config.shared.old ] && rm $HOME/.ssh/config.shared.old
if [ -e $HOME/.ssh/config.shared ]; then
    echo "Creating backup: $HOME/.ssh/config.shared.old"
    cp $HOME/.ssh/config.shared $HOME/.ssh/config.shared.old
    rm $HOME/.ssh/config.shared
fi
echo "Linking $(pwd)/dot/.ssh/config.shared -> $HOME/.ssh/config.shared"
ln -s "$(pwd)/dot/.ssh/config.shared" $HOME/.ssh/config.shared

# ensure ~/.ssh/config includes the shared config
if [ ! -e $HOME/.ssh/config ]; then
    echo "Include ~/.ssh/config.shared" > $HOME/.ssh/config
    chmod 600 $HOME/.ssh/config
    echo "Created $HOME/.ssh/config with Include directive"
elif ! grep -q "config.shared" $HOME/.ssh/config; then
    sed -i'' -e '1s/^/Include ~\/.ssh\/config.shared\n\n/' $HOME/.ssh/config
    echo "Added Include directive to $HOME/.ssh/config"
fi

# claude code
if [ ! -d "$HOME/.claude" ]; then
    echo "Creating: $HOME/.claude"
    mkdir -p $HOME/.claude
fi
if [ ! -d "$HOME/.claude/commands" ]; then
    echo "Creating: $HOME/.claude/commands"
    mkdir -p $HOME/.claude/commands
fi

# CLAUDE.md
[ -e $HOME/.claude/CLAUDE.md.old ] && rm $HOME/.claude/CLAUDE.md.old
if [ -e $HOME/.claude/CLAUDE.md ]; then
    echo "Creating backup: $HOME/.claude/CLAUDE.md.old"
    cp $HOME/.claude/CLAUDE.md $HOME/.claude/CLAUDE.md.old
    rm $HOME/.claude/CLAUDE.md
fi
echo "Linking $(pwd)/dot/claude/CLAUDE.md -> $HOME/.claude/CLAUDE.md"
ln -s "$(pwd)/dot/claude/CLAUDE.md" $HOME/.claude/CLAUDE.md

# settings.json
[ -e $HOME/.claude/settings.json.old ] && rm $HOME/.claude/settings.json.old
if [ -e $HOME/.claude/settings.json ]; then
    echo "Creating backup: $HOME/.claude/settings.json.old"
    cp $HOME/.claude/settings.json $HOME/.claude/settings.json.old
    rm $HOME/.claude/settings.json
fi
echo "Linking $(pwd)/dot/claude/settings.json -> $HOME/.claude/settings.json"
ln -s "$(pwd)/dot/claude/settings.json" $HOME/.claude/settings.json

# commands/ (symlink each .md file)
for cmd in $(pwd)/dot/claude/commands/*.md; do
    cmdname=$(basename "$cmd")
    [ -e "$HOME/.claude/commands/$cmdname.old" ] && rm "$HOME/.claude/commands/$cmdname.old"
    if [ -e "$HOME/.claude/commands/$cmdname" ]; then
        echo "Creating backup: $HOME/.claude/commands/$cmdname.old"
        cp "$HOME/.claude/commands/$cmdname" "$HOME/.claude/commands/$cmdname.old"
        rm "$HOME/.claude/commands/$cmdname"
    fi
    echo "Linking $(pwd)/dot/claude/commands/$cmdname -> $HOME/.claude/commands/$cmdname"
    ln -s "$cmd" "$HOME/.claude/commands/$cmdname"
done
