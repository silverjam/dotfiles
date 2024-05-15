#!/bin/sh

speakers=$(pactl -f json list sinks | jq -r '.[].name' | grep 'Creative.*Pebble.*Pro')
headset=$(pactl -f json list sinks | jq -r '.[].name' | grep 'G435.*Wireless.*Gaming.*Headset')

if pactl get-default-sink | grep -q 'Creative.*Pebble.*Pro'; then
	sink="🎧"
	pactl set-default-sink $headset
else
	sink="🔊"
	pactl set-default-sink $speakers
fi

# See: https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html#command-notify

app_name=
replaces_id=0x9efcbbef
app_icon=
summary="🎶 <===> $sink <===> 🎶"
body='default device updated'
actions='[]'
hints='{"urgency": <1>}'
expire_timeout=5000

gdbus \
	call \
	--session \
	--dest=org.freedesktop.Notifications \
	--object-path=/org/freedesktop/Notifications \
	--method=org.freedesktop.Notifications.Notify \
	"$app_name" \
	"$replaces_id" \
	"$app_icon" \
	"$summary" \
	"$body" \
	"$actions" \
	"$hints" \
	"$expire_timeout"
