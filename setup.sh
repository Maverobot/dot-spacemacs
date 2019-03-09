#!/bin/sh

sudo apt install xclip build-essential cmake python3-dev silversearcher-ag

sudo snap install --channel=edge shellcheck

# Go stuffs
sudo snap install go --classic
go get -u -v github.com/nsf/gocode
go get -u -v github.com/rogpeppe/godef
go get -u -v golang.org/x/tools/cmd/guru
go get -u -v golang.org/x/tools/cmd/gorename
go get -u -v golang.org/x/tools/cmd/goimports
go get -u -v github.com/alecthomas/gometalinter
gometalinter --install --update

git submodule update --init --recursive

if [ -d "ycmd" ]; then
    cd ycmd || return
    python3 build.py --clang-completer
fi
