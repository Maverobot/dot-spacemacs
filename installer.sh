#!/usr/bin/env bash
set -e

readonly SPACEMACS_URL=https://github.com/syl20bnr/spacemacs
readonly SPACEMACS_DIR=${HOME}/.emacs.d
readonly DOTSPACEMACS_DIR=${HOME}/.spacemacs.d
readonly BACKUP_SUFFIX="backup-$(date +"%Y%m%d-%H%M%S")"
readonly DOTSPACEMACS_BRANCH="${1:-master}"

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
    git clone https://github.com/Maverobot/dot-spacemacs.git --recurse-submodules -b ${DOTSPACEMACS_BRANCH} ${DOTSPACEMACS_DIR}
}

###############################################################################
#                             Install dependencies                            #
###############################################################################
function install_dependencies {
    sudo apt update
    sudo apt install -y entr xclip build-essential cmake g++ gcc \
        python3-dev python3-pip python3-wheel python3-venv python3-setuptools \
        libz-dev libtinfo-dev libpq-dev sqlite3 cmake-format ripgrep fd-find

    # Install LLVM for ccls (Ubuntu 24.04 and newer)
    readonly SHORT_CODE=$(lsb_release -cs)
    if [ "${SHORT_CODE}" = "noble" ]; then
        sudo apt install -y llvm-18-dev clang-18 libclang-18-dev
    fi

    sudo snap install --channel=edge shellcheck
    sudo snap install --channel=edge cmake-language-server
    sudo snap install shfmt

    # Install fonts
    curl -Ls https://github.com/hbin/top-programming-fonts/raw/master/install.sh | bash

    # Create ~/org folder if not yet present
    mkdir ~/org -p
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
