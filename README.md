# dot-spacemacs
This is the repository of a personal spacemacs config file. It contains a fully functioning c/c++ development environment with autocompletion via ycmd and syntax checking.
<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [dot-spacemacs](#dot-spacemacs)
    - [Requirements](#requirements)
        - [Emacs26](#emacs26)
        - [Spacemacs](#spacemacs)
    - [Installation](#installation)
    - [Tips and tricks](#tips-and-tricks)
        - [YCMD (a code-completion & comprehension server)](#ycmd-a-code-completion--comprehension-server)
        - [Markdown live preview with glow](#markdown-live-preview-with-glow)

<!-- markdown-toc end -->

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
git checkout 1299f262c
# later version of spacemacs merged ycmd layer into c/c++ layer, which currently does not work out of box with my config.
```
## Installation
To use this config file:
```
git clone https://github.com/Maverobot/dot-spacemacs.git ~/.spacemacs.d

# Backup your ~/.spacemacs file if it already exits.
ln -s ~/.spacemacs.d/.spacemacs ~/.spacemacs -f

# Setup ycmd
cd ~/.spacemacs.d
./setup.sh
```

## Tips and tricks
### YCMD (a code-completion & comprehension server)
For c++ autocompletion to work with cmake projects, it is necessary to compile the projects with flag `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. For example,

```sh
# Go into build folder in cmake project
mkdir build && cd build
# Create compile_commands.json with the flag
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
```

When `YCMD` does not work, e.g. wrong flycheck errors, you can restart the autocompletion server with elisp function `ycmd-open`.

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
