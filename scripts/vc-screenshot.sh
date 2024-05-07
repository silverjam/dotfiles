#!/bin/sh

screenshot_tmp=$(mktemp --suffix=.png)
gnome-screenshot -a --file=$screenshot_tmp
xclip -selection clipboard -t image/png $screenshot_tmp
swappy -f $screenshot_tmp
rm $screenshot_tmp
