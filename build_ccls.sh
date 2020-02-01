#!/usr/bin/env bash

git submodule update --init --recursive

if [ -d "ccls" ]; then
	cd ccls || return
	if [ -d llvm ]; then rm -Rf llvm; fi
	mkdir -p llvm && cd llvm || return
	wget https://releases.llvm.org/9.0.0/clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz
	tar -xf clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz
	cd ..
	cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=./llvm/clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-18.04
	cmake --build Release -- "-j$(nproc)"
fi
