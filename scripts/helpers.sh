#!/usr/bin/env bash
#  Always sourced file - Fake bang path to help editors/linters

#
#  Shorthand, to avoid manually typing package name on multiple
#  locations, easily getting out of sync.
#
# shellcheck disable=SC2034 # used in sourcing scripts
plugin_name="tmux-battery"

#
#  If log_file is empty or undefined, no logging will occur,
#  so comment it out for normal usage.
#
# log_file="/tmp/$plugin_name.log"

#
#  I use an env var TMUX_BIN to point at the used tmux, defined in my
#  tmux.conf, in order to pick the version matching the server running,
#  or when the tmux bin is in fact tmate :)
#  If not found, it is set to whatever is in PATH, so should have no negative
#  impact. In all calls to tmux I use $TMUX_BIN instead in the rest of this
#  plugin.
#
[[ -z "$TMUX_BIN" ]] && TMUX_BIN="tmux"

#
#  If $log_file is empty or undefined, no logging will occur.
#
log_it() {
    if [[ -z "$log_file" ]]; then
        return
    fi
    printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$@" >>"$log_file"
}

get_tmux_option() {
    gtm_option=$1
    gtm_default=$2
    gtm_value=$($TMUX_BIN show-option -gqv "$gtm_option")
    if [[ -z "$gtm_value" ]]; then
        echo "$gtm_default"
    else
        echo "$gtm_value"
    fi
    unset gtm_option
    unset gtm_default
    unset gtm_value
}

command_exists() {
    type "$1" >/dev/null 2>&1
}

battery_status() {
    local battery

    if command_exists upower; then
        battery=$(upower -e | grep -E 'battery|DisplayDevice' | tail -n1)
        upower -i "$battery" | awk '/state/ {print $2}'
    elif command_exists acpi; then
        acpi -b | awk '{gsub(/,/, ""); print tolower($3); exit}'
    elif command_exists pmset; then
        pmset -g batt | awk -F '; *' 'NR==2 { print $2 }'
    elif [[ -d /sys/class/power_supply ]]; then
        # wsl and generic linux without upower/acpi
        battery=$(find /sys/class/power_supply/*/status | tail -n1)
        awk '{print tolower($0);}' "$battery"
    elif command_exists apm; then
        # mostly bsd
        battery=$(apm -a)
        if [[ "$battery" -eq 0 ]]; then
            echo "discharging"
        elif [[ "$battery" -eq 1 ]]; then
            echo "charging"
        fi
    elif command_exists termux-battery-status; then
        termux-battery-status | jq -r '.status' | awk '{printf("%s%", tolower($1))}'
    fi
}
