#!/bin/bash

## Install required bison version:

# wget http://ftp.gnu.org/gnu/bison/bison-3.0.2.tar.xz
# tar xvfJ bison-3.0.2.tar.xz
# cd bison-3.0.2
# ./configure
# make
# sudo checkinstall \
#     -yD --pkgname=mobarakj-bison --nodoc \
#     --exclude=/usr/local/share/info/dir \
#     make install

## Install required regex library:

# apt-get install libonig-dev

INSTALL=$PWD/jq.pkg
BUILD=$PWD/.jq_build

cp -as $PWD/jq $BUILD
cd $BUILD
autoreconf -i
./configure --prefix=$INSTALL
make -j4
make install && rm -rf $BUILD
