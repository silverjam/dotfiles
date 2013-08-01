#!/bin/bash

for revid in `git cherry master|sed 's/\+ //'`; do
    
    git log --stat -1 $revid
    echo

    x=y
    read -p "Diff? [Y/n] " x

    [ x"$x" = x"" ] && x=y
    #[ x"$x" = x"y" ] && git difftool -t gvimdiff "$revid^!"
    [ x"$x" = x"y" ] && git difftool "$revid^!"
    
done
