#!/usr/bin/env bash
set -e

BACKUP_SUFFIX="bk"

###############################################################################
#                              Install Spacemacs                              #
###############################################################################
function install_spacemacs {
    sudo snap install emacs --classic

    [[ -d "~/.emacs.d" ]] && mv -v ~/.emacs.d ~/.emacs.d.bk
    git clone https://github.com/syl20bnr/spacemacs -b develop ~/.emacs.d

    [[ -d "~/.spacemacs.d" ]] && mv -v ~/.spacemacs.d ~/.spacemacs.d.bk
    git clone https://github.com/Maverobot/dot-spacemacs.git --recurse-submodules ~/.spacemacs.d
}

###############################################################################
#                             Install dependencies                            #
###############################################################################
function install_dependencies {
    sudo apt update
    sudo apt install entr xclip build-essential cmake g++ gcc \
        python3-dev python3-pip python3-wheel python3-venv python3-setuptools \
        libz-dev libtinfo-dev notmuch libpq-dev
    sudo python3 -m pip install wheel

    sudo snap install --channel=edge shellcheck
    sudo snap install shfmt

    pip3 install --user rfc6555 # Dependency of offlineimap
    pip3 install --user yapf offlineimap
    pip3 install --user cmake-language-server cmake-format

    # Install fonts
    curl -Ls https://github.com/hbin/top-programming-fonts/raw/master/install.sh | bash

    # Install ripgrep as an alternative to `grep`
    curl -LOs https://github.com/BurntSushi/ripgrep/releases/download/11.0.2/ripgrep_11.0.2_amd64.deb
    sudo dpkg -i ripgrep_11.0.2_amd64.deb

    # Install fd as an alternative to `find`
    curl -LOs https://github.com/sharkdp/fd/releases/download/v8.1.1/fd_8.1.1_amd64.deb
    sudo dpkg -i fd_8.1.1_amd64.deb

    # Install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    nvm install v10.19.0
    nvm use v10.19.0

    # Install marked for generating html from markdown
    npm install -g marked

    # Install tldr to have awesome CLI cheatsheets
    npm install -g tldr
}

###############################################################################
#                        Compile groovy language server                       #
###############################################################################
function compile_groovy_language_server {
    (
        rm /tmp/groovy-language-server -rf && cd /tmp
        git clone https://github.com/prominic/groovy-language-server.git
        cd groovy-language-server && ./gradlew build
        cp -v build/libs/groovy-language-server-all.jar ~/.spacemacs.d/
    )
}

###############################################################################
#                  Compile ccls (C/C++/ObjC language server)                  #
###############################################################################
function compile_ccls {
    (
        cd ~/.spacemacs.d && ./build_ccls.sh
    )
}

###############################################################################
#                        Update Spacemacs and Get ready                       #
###############################################################################
function update_spacemacs {
    /snap/bin/emacs --batch -l ~/.emacs.d/init.el --eval="(configuration-layer/update-packages t)"
}

###############################################################################
#                                Install fonts                                #
###############################################################################
function install_fonts {
    /snap/bin/emacs -u $(id -un) --batch --eval '(all-the-icons-install-fonts t)'
}

###############################################################################
#                             Export Documentation                            #
###############################################################################
function export_documentation {
    (
        cd ~/.spacemacs.d && /snap/bin/emacs spacemacs.org --batch -f org-html-export-to-html && mv -v spacemacs.html docs/index.html
    )
}


echo "Note: if ~/.emacs.d or ~/.spacemacs.d already exists, it will be moved to ~/.emacs.d.${BACKUP_SUFFIX} or ~/.spacemacs.d.${BACKUP_SUFFIX} respectively."

install_dependencies
install_spacemacs
compile_ccls
compile_groovy_language_server
update_spacemacs
install_fonts
export_documentation
