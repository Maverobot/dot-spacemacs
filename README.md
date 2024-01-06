[![Build Status][github-actions-badge]][github-actions-link]
# dot-spacemacs

This is the repository of a personal spacemacs config file. The configurations can be found in

* [init.el](init.el) and
* [spacemacs.org](spacemacs.org) or the [auto-generated documentation](https://maverobot.github.io/dot-spacemacs/)

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
