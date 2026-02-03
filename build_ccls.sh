#!/usr/bin/env bash

set -e

git submodule update --init --recursive

if [ -d "ccls" ]; then
    cd ccls

    readonly SHORT_CODE=$(lsb_release -cs)

    # For Ubuntu 24.04 and newer, use system LLVM packages
    if [ "${SHORT_CODE}" == "noble" ]; then
        # Ubuntu 24.04 - use system LLVM 18
        cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release
        cmake --build Release -- "-j$(nproc)"
    else
        # For older Ubuntu versions, download pre-built LLVM binaries
        mkdir -p llvm && cd llvm

        if [ "${SHORT_CODE}" == "focal" ]; then
            LLVM_BASENAME="clang+llvm-12.0.0-$(uname -m)-linux-gnu-ubuntu-20.04"
            wget -c "https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.0/${LLVM_BASENAME}.tar.xz"
            echo "a9ff205eb0b73ca7c86afc6432eed1c2d49133bd0d49e47b15be59bbf0dd292e  ${LLVM_BASENAME}.tar.xz" | sha256sum --check
        elif [ "${SHORT_CODE}" == "bionic" ]; then
            LLVM_BASENAME="clang+llvm-9.0.0-$(uname -m)-linux-gnu-ubuntu-18.04"
            wget -c "https://releases.llvm.org/9.0.0/${LLVM_BASENAME}.tar.xz"
            echo "a23b082b30c128c9831dbdd96edad26b43f56624d0ad0ea9edec506f5385038d  ${LLVM_BASENAME}.tar.xz" | sha256sum --check
        else
            echo "Error: Unsupported Ubuntu version '${SHORT_CODE}'. Supported versions: noble (24.04), focal (20.04), bionic (18.04)" >&2
            exit 1
        fi

        rm -rf "${LLVM_BASENAME}"
        tar -xf "${LLVM_BASENAME}.tar.xz"

        cd ..
        cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="./llvm/${LLVM_BASENAME}"
        cmake --build Release -- "-j$(nproc)"
    fi
fi
