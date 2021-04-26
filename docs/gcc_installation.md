# GCC Installation

If you are at Ubuntu 18.04 or later, you can simply install it via:

```sh
sudo apt install gcc g++
```

For Ubuntu 16.04,

* Install `gcc-7` and `g++-7` from PPA:
    ```sh
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test
    sudo apt update
    sudo apt install gcc-7 g++-7 -y
    ```

* Set up the symbolic links for `gcc` and `g++` in case you have other versions installed:

    ```sh
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60 \
                             --slave /usr/bin/g++ g++ /usr/bin/g++-7
    sudo update-alternatives --config gcc
    gcc --version
    g++ --version
    ```
