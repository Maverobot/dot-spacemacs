#!/usr/bin/env bash
set -e

sudo apt install xclip build-essential cmake python3-dev python3-pip libz-dev libtinfo-dev notmuch

sudo snap install --channel=edge shellcheck

pip3 install --user rfc6555 # Dependency of offlineimap
pip3 install --user yapf offlineimap
pip3 install --user cmake-language-server cmake-format

sudo snap install shfmt

# Go stuffs
sudo snap install go --classic
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
go get -u -v github.com/nsf/gocode
go get -u -v github.com/rogpeppe/godef
go get -u -v golang.org/x/tools/cmd/guru
go get -u -v golang.org/x/tools/cmd/gorename
go get -u -v golang.org/x/tools/cmd/goimports
go get -u -v github.com/alecthomas/gometalinter
gometalinter --install --update

git submodule update --init --recursive

# Install fonts
curl -L https://github.com/hbin/top-programming-fonts/raw/master/install.sh | bash

# Install ripgrep
curl -LOs https://github.com/BurntSushi/ripgrep/releases/download/11.0.2/ripgrep_11.0.2_amd64.deb
sudo dpkg -i ripgrep_11.0.2_amd64.deb

# Install fd
curl -LOs https://github.com/sharkdp/fd/releases/download/v8.1.1/fd_8.1.1_amd64.deb
sudo dpkg -i fd_8.1.1_amd64.deb

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
. "${HOME}/.bashrc" && nvm install v10.19.0
nvm use v10.19.0

# marked
npm install -g marked

./build_ccls.sh
