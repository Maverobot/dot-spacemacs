#!/bin/sh

sudo apt install build-essential cmake python3-dev

sudo snap install --channel=edge shellcheck

git submodule update --init --recursive

if [ -d "ycmd" ]; then
    cd ycmd || return
    git submodule update --init --recursive
    python3 build.py --clang-completer
fi
