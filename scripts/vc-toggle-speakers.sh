#!/bin/sh

speakers="alsa_output.usb-Creative_Technology_Ltd_Creative_Pebble_Pro_00023CA2B289-01.analog-stereo"
headset="alsa_output.usb-046d_G435_Wireless_Gaming_Headset_V001008005.1-01.analog-stereo"

if pactl get-default-sink | grep -q 'Creative.*Pebble.*Pro'; then
	sink="Headset"
	pactl set-default-sink $headset
else
	sink="Speakers"
	pactl set-default-sink $speakers
fi

# See: https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html#command-notify

app_name=
replaces_id=0x9efcbbef
app_icon=
summary="Sound: $sink defaulted"
body='The default sound output device was changed.'
actions='[]'
hints='{"urgency": <1>}'
expire_timeout=5000

gdbus \
	call \
	--session \
	--dest=org.freedesktop.Notifications \
	--object-path=/org/freedesktop/Notifications \
	--method=org.freedesktop.Notifications.Notify \
	$app_name \
	$replaces_id \
	$app_icon \
	$summary \
	$body \
	$actions \
	$hints \
	$expire_timeout
