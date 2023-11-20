#!/usr/bin/env bash

if [[ $(xdotool getactivewindow getwindowname) =~ WhatsApp* ]]; then
    xdotool getactivewindow windowminimize
else
    if [[ $(xdotool search --name "WhatsApp*" getwindowname) =~ WhatsApp* ]]; then
        xdotool search --name "WhatsApp*" windowactivate
    else
        # Could not find a matching Window, launch a new copy
        gtk-launch vivaldi-hnpfjngllnobngcgfapefoaidbinmjnm-Default
    fi
fi
