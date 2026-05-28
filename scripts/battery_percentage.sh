#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$CURRENT_DIR/helpers.sh"

print_battery_percentage() {
    local battery
    local percentage
    local energy
    local energy_full

    # Try methods in priority order; first one that returns data wins
    battery=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -n1)
    if [[ -n "$battery" ]]; then
        percentage="$(upower -i "$battery" 2>/dev/null | awk '/percentage:/ {print $2}')"
        if [[ -n "$percentage" ]]; then
            echo "${percentage%.*%}"
            return
        fi
        energy="$(upower -i "$battery" 2>/dev/null \
            | awk -v nrg="$energy" '/energy:/ {print nrg+$2}')"
        energy_full=$(upower -i "$battery" 2>/dev/null \
            | awk -v nrgfull="$energy_full" '/energy-full:/ {print nrgfull+$2}')
        if [[ -n "$energy" ]] && [[ -n "$energy_full" ]]; then
            echo "$energy $energy_full" | awk '{printf("%d%%", ($1/$2)*100)}'
            return
        fi
    fi

    acpi -b 2>/dev/null | grep -m 1 -Eo "[0-9]+%" && return

    # If neither upover nor acpi present on a Linux system this should work (even on wsl)
    battery=$(find /sys/class/power_supply/*/capacity 2>/dev/null | tail -n1)
    [[ -n "$battery" ]] && cat "$battery" && return

    # macOS: try precise StateOfCharge first, fall back to Apple approximation
    ioreg -r -k BatteryData 2>/dev/null | grep '"StateOfCharge"=' \
        | sed 's/.*"StateOfCharge"=\([0-9]*\).*/\1%/' && return
    pmset -g batt 2>/dev/null | grep -o "[0-9]\{1,3\}%" && return

    # And finally the odd ones
    apm -l 2>/dev/null && return # legacy BSD battery monitor
    termux-battery-status 2>/dev/null | jq -r '.percentage' 2>/dev/null \
        | awk '{printf("%d%%", $1)}' && return

    echo "??"
}

main() {
    print_battery_percentage
}
main
