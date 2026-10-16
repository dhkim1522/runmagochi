#!/bin/bash
in=$(cat)
command -v jq >/dev/null 2>&1 || { echo "statusline: jq 설치 필요"; exit 0; }
[ -n "$STATUSLINE_DEBUG" ] && echo "$in" > "$STATUSLINE_DEBUG"
now=$(date +%s)
fmt() { # seconds -> 1h57m / 3d15h
  local s=$1; [ "$s" -lt 0 ] && s=0
  if [ "$s" -ge 86400 ]; then echo "$((s/86400))d$((s%86400/3600))h"
  elif [ "$s" -ge 3600 ]; then echo "$((s/3600))h$((s%3600/60))m"
  else echo "$((s/60))m"; fi
}
col() { # pct -> color
  local p=${1%.*}; [ -z "$p" ] && p=0
  if [ "$p" -ge 80 ]; then printf '\033[31m'; elif [ "$p" -ge 50 ]; then printf '\033[33m'; else printf '\033[32m'; fi
}
j() { echo "$in" | jq -r "$1 // empty"; }
model=$(j '.model.display_name')
h5=$(j '.rate_limits.five_hour.used_percentage'); h5r=$(j '.rate_limits.five_hour.resets_at')
wk=$(j '.rate_limits.seven_day.used_percentage'); wkr=$(j '.rate_limits.seven_day.resets_at')
dur=$(j '.cost.total_duration_ms')
ctx=$(j '.context_window.used_percentage')
eff=$(j '.effort.level // .effortLevel')
R='\033[0m'; C='\033[36m'; D='\033[90m'
out="${D}|${R} Model: ${C}${model}${R}"
if [ -n "$h5" ]; then out+=" ${D}|${R} 5h:$(col $h5)$(printf '%.0f' "$h5")%${R}"; [ -n "$h5r" ] && out+="(${D}$(fmt $((h5r-now)))${R})"; fi
if [ -n "$wk" ]; then out+=" ${D}|${R} wk:$(col $wk)$(printf '%.0f' "$wk")%${R}"; [ -n "$wkr" ] && out+="(${D}$(fmt $((wkr-now)))${R})"; fi
[ -n "$dur" ] && out+=" ${D}|${R} session:${C}$(fmt $((dur/1000)))${R}"
[ -n "$ctx" ] && out+=" ${D}|${R} ctx:$(col $ctx)$(printf '%.0f' "$ctx")%${R}"
[ -n "$eff" ] && out+=" ${D}|${R} effort:${C}${eff}${R}"
printf '%b\n' "$out"
