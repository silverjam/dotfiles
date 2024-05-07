#!/bin/sh

xrandr --output HDMI-0 --primary --mode 3440x1440 --rate 99.98 \
	--output eDP-1-1 --mode 1920x1080 --rate 144.00 --right-of HDMI-0
