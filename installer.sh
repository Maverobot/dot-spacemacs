#!/usr/bin/env bash
set -e

readonly SPACEMACS_URL=https://github.com/syl20bnr/spacemacs
readonly SPACEMACS_DIR=${HOME}/.emacs.d
readonly DOTSPACEMACS_DIR=${HOME}/.spacemacs.d
readonly BACKUP_SUFFIX="backup-$(date +"%Y%m%d-%H%M%S")"

###############################################################################
#                              Install Spacemacs                              #
###############################################################################
function install_spacemacs {
    sudo snap install emacs --classic

    if [ -d "${SPACEMACS_DIR}" ]; then
        if [ "$(cd "${SPACEMACS_DIR}" && git config --get remote.origin.url)" = "${SPACEMACS_URL}" ]; then
            cd ${SPACEMACS_DIR} && git stash && git checkout develop && git pull
        else
            mv -v ${SPACEMACS_DIR} ${SPACEMACS_DIR}.${BACKUP_SUFFIX} && git clone "${SPACEMACS_URL}" -b develop ${SPACEMACS_DIR}
        fi
    else
        git clone "${SPACEMACS_URL}" -b develop ${SPACEMACS_DIR}
    fi

    [[ -d "${DOTSPACEMACS_DIR}" ]] && mv -v ${DOTSPACEMACS_DIR} ${DOTSPACEMACS_DIR}.${BACKUP_SUFFIX}
    git clone https://github.com/Maverobot/dot-spacemacs.git --recurse-submodules ${DOTSPACEMACS_DIR}
}

###############################################################################
#                             Install dependencies                            #
###############################################################################
function install_dependencies {
    sudo apt update
    sudo apt install -y entr xclip build-essential cmake g++ gcc \
        python3-dev python3-pip python3-wheel python3-venv python3-setuptools \
        libz-dev libtinfo-dev notmuch libpq-dev sqlite3
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
        cp -v build/libs/groovy-language-server-all.jar ${DOTSPACEMACS_DIR}/
    )
}

function download_plantuml {
    (
        cd ${DOTSPACEMACS_DIR}
        wget -nc -q --show-progress http://sourceforge.net/projects/plantuml/files/plantuml.jar
    )
}

###############################################################################
#                  Compile ccls (C/C++/ObjC language server)                  #
###############################################################################
function compile_ccls {
    (
        cd ${DOTSPACEMACS_DIR} && ./build_ccls.sh
    )
}

###############################################################################
#                        Update Spacemacs and Get ready                       #
###############################################################################
function update_spacemacs {
    # Installs missing packages and it can fail
    /snap/bin/emacs -l ${SPACEMACS_DIR}/init.el --batch --eval 'nil' || echo "There occurred an error during the installation of missing packages"
    # Updates the packges to their latest versions
    /snap/bin/emacs -l ${SPACEMACS_DIR}/init.el --batch --eval '(configuration-layer/update-packages t)'
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
        cd ${DOTSPACEMACS_DIR}
        /snap/bin/emacs --batch -l ~/.emacs.d/init.el spacemacs.org --eval "(setq org-html-htmlize-output-type 'css)" -f org-html-export-to-html
        mv -v spacemacs.html docs/index.html
    )
}


echo "Note:"
echo "  - If ${SPACEMACS_DIR} already exists but is not from 'syl20bnr/spacemacs', it will be moved to ${SPACEMACS_DIR}.${BACKUP_SUFFIX}."
echo "  - If ${SPACEMACS_DIR} already exists and is from 'syl20bnr/spacemacs', the uncommitted changes will be stashed."
echo "  - If ${DOTSPACEMACS_DIR} already exists, it will be moved to ${DOTSPACEMACS_DIR}.${BACKUP_SUFFIX}."

install_dependencies
install_spacemacs
compile_ccls
update_spacemacs
install_fonts
export_documentation
compile_groovy_language_server
download_plantuml
