#!/bin/sh

date
printf 'ioreg: %s\n' "$(ioreg -r -k BatteryData 2>/dev/null | grep '"StateOfCharge"=' \
    | sed 's/.*"StateOfCharge"=\([0-9]*\).*/\1%/')"
printf 'pmset: %s\n' "$(pmset -g batt 2>/dev/null | grep -o "[0-9]\{1,3\}%")"
