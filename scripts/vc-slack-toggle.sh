#!/usr/bin/env bash

app_name="- Slack"

if xdotool getactivewindow getwindowname | grep -qiE ".*${app_name}.*"; then
  xdotool getactivewindow windowminimize
else
  #gtk-launch slack
  flatpak run com.slack.Slack
fi
