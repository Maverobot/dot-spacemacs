[![Build Status][github-actions-badge]][github-actions-link]

# dot-spacemacs

Personal Spacemacs configuration, organized as a literate Org setup.

- [`spacemacs.org`](spacemacs.org): main configuration and source documentation
- [`init.el`](init.el): Spacemacs entry point
- [Generated documentation][generated-docs]

## Installation

### Automatic Ubuntu setup

The installer is CI-tested on Ubuntu 24.04. It installs Emacs, Spacemacs,
required packages, fonts, language servers, and this configuration.

```sh
curl -fsSL https://raw.githubusercontent.com/Maverobot/dot-spacemacs/master/installer.sh | bash
```

The script uses `sudo` for system packages and backs up existing
`~/.emacs.d` / `~/.spacemacs.d` directories when needed. Review
[`installer.sh`](installer.sh) first if you already have local Emacs config.

### Manual setup

```sh
sudo snap install emacs --classic
git clone https://github.com/syl20bnr/spacemacs -b develop ~/.emacs.d
git clone --recurse-submodules https://github.com/Maverobot/dot-spacemacs.git ~/.spacemacs.d
[ -f ~/.spacemacs ] && mv ~/.spacemacs ~/.spacemacs.bk
cd ~/.spacemacs.d && ./setup.sh
```

For C/C++ support, `ccls` needs GCC >= 7.5; see the
[GCC installation guide][gcc-installation]. To build only `ccls`:

```sh
cd ~/.spacemacs.d && ./build_ccls.sh
```

## Resources

- [Tips and tricks][tips-and-tricks]
- [Generated documentation][generated-docs]

[github-actions-badge]: https://github.com/maverobot/dot-spacemacs/actions/workflows/main.yml/badge.svg?branch=master
[github-actions-link]: https://github.com/Maverobot/dot-spacemacs/actions
[generated-docs]: https://maverobot.github.io/dot-spacemacs/
[gcc-installation]: https://github.com/Maverobot/dot-spacemacs/blob/master/docs/gcc_installation.md
[tips-and-tricks]: https://github.com/Maverobot/dot-spacemacs/blob/master/docs/tips_and_tricks.md
