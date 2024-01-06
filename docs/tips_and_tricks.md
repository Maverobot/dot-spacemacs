# Tips and tricks
## ccls
For language server to work, it is necessary to compile the projects with flag `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. Take cmake project for example,

```sh
# Go into build folder in cmake project
mkdir build && cd build
# Create compile_commands.json with the flag
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
```

## Markdown live preview
Call `M-x start_glow_viewer` in a markdown buffer. See [here][start-glow-viewer] for details.

In order to use this feature, `glow` has to be installed manually.

```sh
sudo snap install go --classic
go get github.com/charmbracelet/glow
```

[start-glow-viewer]: https://github.com/Maverobot/dot-spacemacs/blob/master/spacemacs.org#glow-the-markdown-viewer
