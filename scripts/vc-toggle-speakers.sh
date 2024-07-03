#!/bin/bash

readonly SPEAKER_PATTERN='Creative.*Pebble.*Pro'
readonly HEADSET_PATTERN='G435.*Wireless.*Gaming.*Headset'

readonly HEADSET_EMOJI="🎧"
readonly SPEAKER_EMOJI="🔊"

[[ -z "$DEBUG" ]] || set -x
set -e

send_notif() {
	# See: https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html#command-notify

	local summary="🎶 <===> $1 <===> 🎶"
	shift
	local body=$1
	shift

	local app_name=
	local replaces_id=0x9efcbbef
	local app_icon=
	local actions='[]'
	local hints='{"urgency": <1>}'
	local expire_timeout=5000

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
}

speakers=$(pactl -f json list sinks | jq -r '.[].name' | grep $SPEAKER_PATTERN || :)
headset=$(pactl -f json list sinks | jq -r '.[].name' | grep $HEADSET_PATTERN || :)

if [[ -z "$speakers" ]]; then
	send_notif "$SPEAKER_EMOJI" 'speakers not found'
	exit 1
fi

if [[ -z "$headset" ]]; then
	send_notif "$HEADSET_EMOJI" 'headset not found'
	exit 1
fi

if pactl get-default-sink | grep -q 'Creative.*Pebble.*Pro'; then
	sink=$HEADSET_EMOJI
	pactl set-default-sink $headset
else
	sink=$SPEAKER_EMOJI
	pactl set-default-sink $speakers
fi

send_notif "$sink" 'default device updated'
