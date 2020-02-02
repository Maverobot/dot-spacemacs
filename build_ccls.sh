#!/usr/bin/env bash

git submodule update --init --recursive

if [ -d "ccls" ]; then
	cd ccls || return
	if [ -d llvm ]; then rm -Rf llvm; fi
	mkdir -p llvm && cd llvm || return
	LLVM_BASENAME="clang+llvm-9.0.0-$(uname -m)-linux-gnu-ubuntu-$(lsb_release -rs)"
	wget "https://releases.llvm.org/9.0.0/${LLVM_BASENAME}.tar.xz"
	tar -xf "${LLVM_BASENAME}.tar.xz"
	cd ..
	cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="./llvm/${LLVM_BASENAME}"
	cmake --build Release -- "-j$(nproc)"
fi
