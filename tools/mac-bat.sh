#!/bin/sh

#
#  Displays
#   ioreg  battery actual state of charge
#   pmset  Apple approximation of charge taking in aging, temp load factor etc
#

date
printf 'ioreg: %s\n' "$(ioreg -r -k BatteryData 2>/dev/null | grep '"StateOfCharge"=' \
    | sed 's/.*"StateOfCharge"=\([0-9]*\).*/\1%/')"
printf 'pmset: %s\n' "$(pmset -g batt 2>/dev/null | grep -o "[0-9]\{1,3\}%")"
