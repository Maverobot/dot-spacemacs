[![Build Status][github-actions-badge]][github-actions-link]
# dot-spacemacs

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [dot-spacemacs](#dot-spacemacs)
    - [Installation](#installation)
        - [Automatic](#automatic)
        - [Manuel](#manuel)
            - [Requirements](#requirements)
            - [Configuration](#configuration)

<!-- markdown-toc end -->

This is the repository of a personal spacemacs config file. It contains a fully functioning c/c++ development environment with [ccls](https://github.com/MaskRay/ccls), which is a C/C++/ObjC language server supporting cross references, hierarchies, completion and semantic highlighting.

The content of the configuration can be found in the [spacemacs.org](spacemacs.org "Spacemacs configuration in org file") file.

## Installation

### Automatic

If you are using `Ubuntu 18.04` or `Ubuntu 20.04`, you can install the entire setup, including `emacs`, `spacemacs`, utility packages etc, using the following simple command:

```sh
curl -o- https://raw.githubusercontent.com/Maverobot/dot-spacemacs/master/installer.sh | bash
```

Root privileges will be needed by the script for package installation via `apt`, `snap` and `dpkg`. When in doubt, feel free to check out [installer.sh][installer.sh].


### Manual

<details>
  <summary>Click me</summary>

#### Requirements

* Emacs
  ```sh
  sudo snap install emacs --classic
  ```

* Spacemacs
  ```sh
  git clone https://github.com/syl20bnr/spacemacs -b develop ~/.emacs.d
  ```

* `gcc` >= 7.5 is needed to compile `ccls`. See [here][gcc-installation] for installation guide.

* Fonts for the themes:

  ```sh
  emacs -u $(id -un) --batch --eval '(all-the-icons-install-fonts t)'
  ```

#### Configuration

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

</details>

## Other stuffs

* [Tips and tricks][tips-and-tricks]

[github-actions-badge]: https://github.com/maverobot/dot-spacemacs/actions/workflows/main.yml/badge.svg?branch=master
[github-actions-link]: https://github.com/Maverobot/dot-spacemacs/actions
[installer.sh]: https://raw.githubusercontent.com/Maverobot/dot-spacemacs/master/installer.sh
[gcc-installation]: https://github.com/Maverobot/dot-spacemacs/blob/master/docs/gcc_installation.md
[tips-and-tricks]: https://github.com/Maverobot/dot-spacemacs/blob/master/docs/tips_and_tricks.md
