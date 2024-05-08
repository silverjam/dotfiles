#!/usr/bin/env bash

app_name="- Slack"
launcher_name="slack"

if xdotool getactivewindow getwindowname | grep -qiE ".*${app_name}.*"; then
	xdotool getactivewindow windowminimize
else
	gtk-launch $launcher_name
fi
