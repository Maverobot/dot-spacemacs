#!/usr/bin/env bash
set -e

git submodule update --init --recursive

sudo apt install xclip build-essential cmake python3-dev python3-pip libz-dev libtinfo-dev sox cmake-format ripgrep fd-find

sudo snap install --channel=edge shellcheck
sudo snap install --channel=edge cmake-language-server
sudo snap install shfmt

# Install fonts
curl -L https://github.com/hbin/top-programming-fonts/raw/master/install.sh | bash

# Install Fira Code font
mkdir -p ~/.local/share/fonts
curl -fsSL -o /tmp/FiraCode.zip "https://github.com/tonsky/FiraCode/releases/latest/download/Fira_Code_v6.2.zip"
unzip -o /tmp/FiraCode.zip -d /tmp/FiraCode
cp /tmp/FiraCode/ttf/*.ttf ~/.local/share/fonts/
fc-cache -f

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

nvm install v16.2.0
nvm use v16.2.0

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
