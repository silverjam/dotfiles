#!/usr/bin/env bash

app_name="Gemini"
launcher_name="vivaldi-iopbjjhffimhfbmbfojndpennnipdpid-Default"

if xdotool getactivewindow getwindowname | grep -q $app_name; then
	echo "Minimizing"
	xdotool getactivewindow windowminimize
else
	if xdotool search --name $app_name getwindowname | grep -q $app_name; then
		echo "Activating"
		xdotool search --name $app_name windowactivate
	else
		echo "Launching"
		gtk-launch ${launcher_name}
	fi
fi
