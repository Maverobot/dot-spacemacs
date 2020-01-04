#!/usr/bin/env bash

if ! [ -x "$(command -v entr)" ]; then
	echo -e 'Error: entr is not installed. Install it with \n\n\tsudo apt install entr\n' >&2
	read -p "Press enter to exit."
	exit 1
fi

if ! [ -x "$(command -v glow)" ]; then
	echo -e 'Error: glow is not installed. Install it with \n\n\tsudo snap install go --classic\n\tgo get github.com/charmbracelet/glow\n' >&2
	read -p "Press enter to exit."
	exit 1
fi

find "$1" | entr -c glow /_
