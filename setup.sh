#!/usr/bin/env bash
set -e

git submodule update --init --recursive

sudo apt install xclip build-essential cmake python3-dev python3-pip libz-dev libtinfo-dev notmuch

sudo snap install --channel=edge shellcheck

pip3 install --user rfc6555 # Dependency of offlineimap
pip3 install --user yapf offlineimap
pip3 install --user cmake-language-server cmake-format

sudo snap install shfmt

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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

nvm install v10.19.0
nvm use v10.19.0

# marked
npm install -g marked

# tldr
npm install -g tldr

./build_ccls.sh

# groovy-langurage-server
rm /tmp/groovy-language-server -rf && cd /tmp
git clone https://github.com/prominic/groovy-language-server.git
cd groovy-language-server && ./gradlew build
cp -v build/libs/groovy-language-server-all.jar ~/.spacemacs.d/
