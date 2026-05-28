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

cache_check() {
    [[ -f "$f_cached_result" ]] || return

    local current_time
    local file_mod_time
    local time_diff

    current_time=$(date +%s)

    # if one assignment fails, try the next one...
    file_mod_time=$(
        # date -r should normally work and is faster than stat
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
        # cache miss
        rm -f "$f_cached_result"
    fi
}

clear_battery_status() {
    echo "" >"$f_cached_result"
}

check_status() {
    local status
    local percentage
    local icon_status
    local color_bg
    local remain

    status=$(battery_status)
    percentage="$("$CURRENT_DIR"/battery_percentage.sh | sed -e 's/%//')"
    echo "><> status[$status] percentage[$percentage]" >/dev/stderr

    if pgrep AlDente >/dev/null && [[ "$percentage" -ge "$alldente_is_charged_level" ]]; then
        # If AlDente is used and power is at least alldente_is_charged_level, assume
        # that if system believes it runs on battery, it is a non-issue.
        clear_battery_status
    else
        icon_status=$(print_icon_status "$status")

        if [[ "$status" != "discharging" ]] && [[ "$percentage" -ge 99 ]]; then
            # If almost full or better and plugged in, we do not need to see
            # details about battery level.
            clear_battery_status
        else
            color_bg="$(print_color_charge bg)"
            remain=$(print_battery_remain)
            printf "%s" "${color_bg}$icon_status ${percentage} ${remain}#[default] " \
                >"$f_cached_result"
        fi
    fi

    cat "$f_cached_result"
}

#===============================================================
#
#   Main
#
#===============================================================

CURRENT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PLUGIN_DIR="$(dirname "$CURRENT_DIR")"

# This script may be triggered frequently, potentially every 5 seconds or less.
# On slower systems, this frequent execution can lead to noticeable delays
# due to the script’s substantial processing requirements.
# To improve responsiveness and reduce system load, a cached result is used
# to limit full processing to once every 30 seconds.
# This approach roughly reduces the runtime by a factor of twenty on a cache hit.

f_cached_result="$PLUGIN_DIR"/smart_status.cache
cache_max_age=30 # seconds

# Since AlDente fakes system to be on battery power if charge is above its target
# level, the practical approach seems to be to simply assume fully charged
# if at or above AlDente level (minus Sailing mode if used)
alldente_is_charged_level=75

cache_check

# If the cache did not handle the request, proceed with recalculating...

# shellcheck disable=SC1091
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/battery_icon_status.sh" >/dev/null
source "$CURRENT_DIR/battery_percentage.sh" >/dev/null
source "$CURRENT_DIR/battery_color_charge.sh" >/dev/null
source "$CURRENT_DIR/battery_remain.sh" >/dev/null
#short=false

check_status
