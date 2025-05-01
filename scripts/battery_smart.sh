#!/usr/bin/env bash
#  shellcheck disable=SC1091
#  Directives for shellcheck directly after bang path are global
#
#   Copyright (c) 2021,2022,2024: Jacob.Lundqvist@gmail.com
#   License: MIT
#
#   Part of https://github.com/jaclu/tmux-battery
#
#   Version: 1.2.0 2024-09-04
#

CURRENT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PLUGIN_DIR="$(dirname "$CURRENT_DIR")"

# This script may be triggered frequently, potentially every 5 seconds or less.
# On slower systems, this frequent execution can lead to noticeable delays
# due to the script’s substantial processing requirements.
# To improve responsiveness and reduce system load, a cached result is used
# to limit full processing to once every 30 seconds.
# This approach roughly reduces the runtime by a factor of twenty on cache hit.

f_cached_result="$PLUGIN_DIR"/smart_status.cache
cache_max_age=30

if [[ -f "$f_cached_result" ]]; then
    current_time=$(date +%s)

    # if one assignment fails, try the next one...
    file_mod_time=$( # date -r should normally work and is faster than stat
        date -r "$f_cached_result" +%s 2>/dev/null
    ) || file_mod_time=$( # GNU/Linux fallback
        stat -c %Y "$f_cached_result" 2>/dev/null
    ) || file_mod_time=$( # BSD & Darwin fallback
        stat -f %m "$f_cached_result" 2>/dev/null
    ) || file_mod_time=0 # invalidate cache by setting a zero timestamp

    time_diff=$((current_time - file_mod_time))
    if ((time_diff < cache_max_age)); then
        cat "$f_cached_result"
        exit 0
    else
        rm -f "$f_cached_result"
    fi
fi

# If the cache did not handle the request, proceed with recalculating...

# shellcheck disable=SC1091
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/battery_icon_status.sh" >/dev/null
source "$CURRENT_DIR/battery_percentage.sh" >/dev/null
source "$CURRENT_DIR/battery_color_charge.sh" >/dev/null
source "$CURRENT_DIR/battery_remain.sh" >/dev/null
#short=false

main() {
    #get_icon_status_settings
    local color_bg
    local percentage
    local status
    local icon_status
    local remain

    status=$(battery_status)
    percentage="$("$CURRENT_DIR"/battery_percentage.sh | sed -e 's/%//')"
    icon_status=$(print_icon_status "$status")

    if [[ "$percentage" -ge 65 ]] && [[ -d "/Applications/AlDente.app" ]]; then
        # If AlDente is used 80% is considered fully charged, and if SailingMode
        # is enabled it is allowed to fluctuate down to 75%
        echo "" >"$f_cached_result"
    elif [[ "$status" != "discharging" ]] && [[ "$percentage" -ge 99 ]]; then
        # If almost full or better and plugged in, we do not need to see
        # details about battery. An icon indicating power is plugged in,
        # should be enough
        printf "%s" "$icon_status" >"$f_cached_result"
    else
        #  Variables only retrieved when needed, in order to cut down overhead
        color_bg="$(print_color_charge bg)"
        remain=$(print_battery_remain)
        printf "%s" "${color_bg}$icon_status ${percentage} ${remain}#[default]" >"$f_cached_result"
    fi
    cat "$f_cached_result"
}

main
