# dot-spacemacs
<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [dot-spacemacs](#dot-spacemacs)
    - [Requirements](#requirements)
        - [Emacs26](#emacs26)
        - [Spacemacs](#spacemacs)
        - [gcc-7](#gcc-7)
        - [Fonts](#fonts)
    - [Installation](#installation)
    - [Tips and tricks](#tips-and-tricks)
        - [CCLS](#ccls)
        - [Markdown live preview with glow](#markdown-live-preview-with-glow)

<!-- markdown-toc end -->

This is the repository of a personal spacemacs config file. It contains a fully functioning c/c++ development environment with [ccls](https://github.com/MaskRay/ccls), which is a C/C++/ObjC language server supporting cross references, hierarchies, completion and semantic highlighting.

## Requirements
### Emacs26
To install emacs26:
```
sudo add-apt-repository ppa:kelleyk/emacs
sudo apt-get update
sudo apt install emacs26
```
### Spacemacs
```
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
cd ~/.emacs.d
git checkout develop
```

### gcc-7
gcc-7 is need to compile `ccls`. Run the following in the terminal:

Install the gcc-7 packages:

    sudo apt-get install -y software-properties-common
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test
    sudo apt update
    sudo apt install g++-7 -y

Set it up so the symbolic links `gcc`, `g++` point to the newer version:

    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60 \
                             --slave /usr/bin/g++ g++ /usr/bin/g++-7
    sudo update-alternatives --config gcc
    gcc --version
    g++ --version

### Fonts
In `emacs`, run `M-x all-the-icons-install-fonts`.


## Installation
To use this config file:
```
git clone https://github.com/Maverobot/dot-spacemacs.git ~/.spacemacs.d

# Backup your ~/.spacemacs file if it already exits.
ln -s ~/.spacemacs.d/.spacemacs ~/.spacemacs -f

# Setup everything including ccls
cd ~/.spacemacs.d
./setup.sh

# Setup only ccls for c/c++ IDE
cd ~/.spacemacs.d
./build_ccls.sh
```

## Tips and tricks
### CCLS
For language server to work, it is necessary to compile the projects with flag `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. Take cmake project for example,

```sh
# Go into build folder in cmake project
mkdir build && cd build
# Create compile_commands.json with the flag
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
```

### Markdown live preview with glow
To use it, simply in the markdown buffer run elisp function `start_glow_viewer`, which is defined in `.spacemacs`.

* Install [glow](https://github.com/charmbracelet/glow):

```sh
# MacOS
brew install charmbracelet/homebrew-tap/glow

# Arch Linux (btw)
yay -S glow

# FreeBSD
pkg install glow

# Ubuntu
sudo snap install go --classic
go get github.com/charmbracelet/glow
```

* Install [entr](https://github.com/clibs/entr):

```sh
sudo apt install entr
```
