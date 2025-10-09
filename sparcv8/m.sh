#!/bin/bash
#set -x

if [ "$1" == "" ]; then
    echo "Usage: m.sh <sourcefile> [optlevel]"
    echo "  optlevel: 0, 1, 2 (default), 3, fast"
    exit 1
fi

if ! test -f "$1.s"; then
    echo "File $1.s not found!"
    exit 1
fi

if [ "$2" == "" ]; then
    optlevel="2"
else
    optlevel="$2"
fi

gccpath="../gcc-14.3.0/bin"

# use -mcpu=v7 to generate mulscc instructions for integer multiplication
$gccpath/sparc-linux-gcc -mcpu=v8 $1.s -o $1.elf -l:libstdc++.a -static

# generate disassembly
$gccpath/sparc-buildroot-linux-uclibc-objdump -d $1.elf >$1.txt

#cp $1.s /mnt/c/users/david/onedrive/sparcos/c_tests
#cp $1.elf /mnt/c/users/david/onedrive/sparcos/c_tests
#cp $1.txt /mnt/c/users/david/onedrive/sparcos/c_tests
