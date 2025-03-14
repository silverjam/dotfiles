#!/usr/bin/env bash

## app_name="Gemini"
## launcher_name="vivaldi-iopbjjhffimhfbmbfojndpennnipdpid-Default"
##
## if xdotool getactivewindow getwindowname | grep -q $app_name; then
## 	echo "Minimizing"
## 	xdotool getactivewindow windowminimize
## else
## 	if xdotool search --name $app_name getwindowname | grep -q $app_name; then
## 		echo "Activating"
## 		xdotool search --name $app_name windowactivate
## 	else
## 		echo "Launching"
## 		gtk-launch ${launcher_name}
## 	fi
## fi

if screen -ls | grep -q \.radio; then
  echo "Toggling mute"
  fish -c 'mute-radio-toggle'
else
  echo "Starting radio"
  fish -c 'stream-radio "Live 105.3"'
fi
