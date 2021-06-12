#!/usr/bin/env bash

set -e

git submodule update --init --recursive

if [ -d "ccls" ]; then
    cd ccls || return
    if [ -d llvm ]; then rm -Rf llvm; fi
    mkdir -p llvm && cd llvm || return

    readonly SHORT_CODE=$(lsb_release -cs)
    if [ "${SHORT_CODE}" == "focal" ]; then
        LLVM_BASENAME="clang+llvm-12.0.0-$(uname -m)-linux-gnu-ubuntu-20.04"
        wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.0/${LLVM_BASENAME}.tar.xz"
    elif [ "${SHORT_CODE}" == "bionic" ]; then
        LLVM_BASENAME="clang+llvm-9.0.0-$(uname -m)-linux-gnu-ubuntu-18.04"
        wget "https://releases.llvm.org/9.0.0/${LLVM_BASENAME}.tar.xz"
    fi

    tar -xf "${LLVM_BASENAME}.tar.xz"
    cd ..
    cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="./llvm/${LLVM_BASENAME}"
    cmake --build Release -- "-j$(nproc)"
fi
