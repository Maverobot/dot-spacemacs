# Tips and tricks
## ccls
For language server to work, it is necessary to compile the projects with flag `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. Take cmake project for example,

```sh
# Go into build folder in cmake project
mkdir build && cd build
# Create compile_commands.json with the flag
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
```

## Python xref with Pyright and uv
Pyright can resolve third-party definitions only when it can see the project's
Python environment. With `lsp-pyright`, a project-local `.venv` is enough: it
searches upward from the Python buffer for `.venv/` and sends that
`.venv/bin/python` to Pyright as `python.pythonPath`.

```sh
cd /path/to/python/project
uv venv .venv
uv pip install -r requirements/dev.txt
```

Then restart the LSP workspace or reopen the buffer. If `uv` rejects pip-only
requirement syntax, use `uv venv --seed .venv` and install with
`.venv/bin/python -m pip install -r requirements/dev.txt`.

Pyright and Ruff run as separate LSP processes for each Python project. This
keeps each project's `.venv`, analysis scope, and file watches isolated. Use
`M-x lsp-workspace-restart` after creating or changing an environment.

During an explicit restart, lsp-mode can report that the old process "has
exited (killed)" and that a queued send reached a killed process. This is
expected when the replacement process initializes and responds normally; it is
not by itself an out-of-memory failure. In single-root mode Pyright 1.1.408 can
log an empty service name; confirm the workspace root, project `.venv`,
project-only file count, and successful requests instead of treating that label
alone as a failure.

Use `M-x lsp-workspace-folders-remove` to remove an accidentally imported
folder. Do not delete `.lsp-session-v1` wholesale because it also stores roots
for unrelated language servers. Generated `.ros2_ws` trees are excluded from
recursive LSP watching, so restart Pyright and Ruff after rebuilding generated
ROS Python interfaces.

## Markdown live preview
Call `M-x start_glow_viewer` in a markdown buffer. See [here][start-glow-viewer] for details.

In order to use this feature, `glow` has to be installed manually.

```sh
sudo snap install go --classic
go get github.com/charmbracelet/glow
```

[start-glow-viewer]: https://github.com/Maverobot/dot-spacemacs/blob/master/spacemacs.org#glow-the-markdown-viewer
