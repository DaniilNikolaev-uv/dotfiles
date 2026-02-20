#!/usr/bin/env bash

bat_dir="/sys/class/power_supply/BAT1"
ac_dir="/sys/class/power_supply/ACAD"

if [[ ! -d "$bat_dir" ]]; then
  echo '{"text":" N/A","alt":"no battery","class":"unknown"}'
  exit 0
fi

capacity=$(cat "$bat_dir/capacity" 2>/dev/null || echo 0)
status=$(cat "$bat_dir/status" 2>/dev/null || echo Unknown)

icon="󰂃"
if   (( capacity >= 95 )); then icon="󰁹"
elif (( capacity >= 80 )); then icon="󰂂"
elif (( capacity >= 60 )); then icon="󰂁"
elif (( capacity >= 40 )); then icon="󰂀"
elif (( capacity >= 20 )); then icon="󰁾"
else icon="󰂃"
fi

class="discharging"
if [[ "$status" == "Charging" ]]; then
  class="charging"
elif [[ "$status" == "Full" ]]; then
  class="full"
fi

text="$icon ${capacity}%"
alt="${capacity}% ${status}"

printf '{"text":"%s","alt":"%s","class":"%s"}\n' "$text" "$alt" "$class"

