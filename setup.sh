#!/bin/sh

sudo apt install build-essential cmake python3-dev silversearcher-ag

git submodule update --init --recursive

if [ -d "ycmd" ]; then
    cd ycmd
    git submodule update --init --recursive
    python3 build.py --clang-completer
fi
