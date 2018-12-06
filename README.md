# dot-spacemacs
This is the repository of a personal spacemacs config file.
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

## YCMD
For cmake projects it is necessary to compile the projects with flag:
```
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
``` 
