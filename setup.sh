#!/bin/sh

sudo apt install xclip build-essential cmake python3-dev silversearcher-ag

sudo snap install --channel=edge shellcheck

git submodule update --init --recursive

if [ -d "ycmd" ]; then
    cd ycmd || return
    git submodule update --init --recursive
    python3 build.py --clang-completer
fi
