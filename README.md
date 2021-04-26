# dot-spacemacs
<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [dot-spacemacs](#dot-spacemacs)
    - [Requirements](#requirements)
    - [Configuration](#configuration)
    - [Tips and tricks](#tips-and-tricks)

<!-- markdown-toc end -->

This is the repository of a personal spacemacs config file. It contains a fully functioning c/c++ development environment with [ccls](https://github.com/MaskRay/ccls), which is a C/C++/ObjC language server supporting cross references, hierarchies, completion and semantic highlighting.

The content of the configuration can be found in the [spacemacs.org](spacemacs.org "Spacemacs configuration in org file") file.

## Requirements

* Emacs
  ```sh
  sudo snap install emacs --candidate --classic
  ```

* Spacemacs
  ```sh
  git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
  cd ~/.emacs.d
  git checkout develop
  ```

* `gcc` >= 7.5 is needed to compile `ccls`. See [here][gcc-installation] for installation guide.

## Configuration

* Clone the repo
  ```sh
  git clone https://github.com/Maverobot/dot-spacemacs.git ~/.spacemacs.d
  ```

* Backup your `~/.spacemacs` file somewhere. The spacemacs will now use `~/.spacemacs.d/init.el` as the init-file instead.
  ```sh
  mv ~/.spacemacs ~/.spacemacs.bk
  ```

* Setup everything including ccls
  ```sh
  cd ~/.spacemacs.d && ./setup.sh
  ```

* Setup only ccls for c/c++ IDE
  ```sh
  cd ~/.spacemacs.d && ./build_ccls.sh
  ```

## Tips and tricks
##### CCLS
For language server to work, it is necessary to compile the projects with flag `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. Take cmake project for example,

```sh
# Go into build folder in cmake project
mkdir build && cd build
# Create compile_commands.json with the flag
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
```

##### Markdown live preview with glow
Call `M-x start_glow_viewer` in a markdown buffer. See [here][start-glow-viewer] for details.

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

[gcc-installation]: https://github.com/Maverobot/dotspacemacs/blob/master/docs/gcc_installation.md
[start-glow-viewer]: https://github.com/Maverobot/dot-spacemacs/blob/master/spacemacs.org#glow-the-markdown-viewer
