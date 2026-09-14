#!/bin/bash
#
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU
#General Public License as published by the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
#the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
#License for more details.
#
#You should have received a copy of the GNU General Public License along with this program. If not, see
#<https://www.gnu.org/licenses/>. 
#
#IPMI Fan Control Override Script
#
#DISCLAIMER: This has been tested on Dell R720 servers and some reports confirm that it works on other Dell servers. You need to test the ipmitool commands before implementing in your environment!
#
#SETUP and USAGE:
#
# crontab -l > mycron
# echo "#" >> mycron
# echo "# At every minute" >> mycron
# echo "*/1 * * * * root /bin/bash /scripts/fan_control.sh 2>&1 | /usr/bin/logger -t fan_control" >> mycron
# crontab mycron
# rm mycron
# chmod +x /scripts/fan_control.sh
#
#SCRIPT START
DATE=$(date +%y%m%d-%H%M%S)

#===Variables===
#minimum fan speed (%)
MINSPEED=25
#fan speed (%) to grow per degree celsius
GROWFACTOR=2
#fan speed (%) to set in base16 when temps are below TEMPTHRESHOLDLOW
MINSPEEDBASE16=19
#check these on your systems, run ipmitool sdr type temperature and check for CPU sensors
SENSORNAME="0Eh"
SENSORNAME2="0Fh"
#low temperature (deg C) for fan calculations
TEMPTHRESHOLDLOW=45
#high temperature (dec C) over which fans are set to max
TEMPTHRESHOLDHIGH=70

#===iDRAC Variables===
#iDRAC account that must have administrator permissions for IPMI over LAN
USERACCOUNT="<iDRAC username>"
PASSWORD="<iDRAC password>"
#set in iDRAC Settings > Network > IPMI Settings > Encryption Key
SOL_KEY="<iDRAC IPMI Encryption Key>"
#do not change
PROTOCOL="lanplus"
#array of remote hosts to manage fans on
HOSTS=("192.168.0.11" "192.168.0.12" "192.168.0.13")

#===LOCALHOST Fan control===
#you can delete this section if not needed
T1=$(ipmitool sdr type temperature | grep $SENSORNAME | cut -d"|" -f5 | cut -d" " -f2)
T2=$(ipmitool sdr type temperature | grep $SENSORNAME2 | cut -d"|" -f5 | cut -d" " -f2)
if [[ -z $T1 || -z $T2 ]]; then
    TC=$TEMPTHRESHOLDHIGH
elif (( $T1 > $T2 )); then
    TC=$T1
else
    TC=$T2
fi
OUT="FAN-V3.0-${DATE}:LOCALHOST:"

if (( $TC >= $TEMPTHRESHOLDHIGH )); then
    ipmitool raw 0x30 0x30 0x01 0x01 >/dev/null
    echo "${OUT}CPU0=${T1}C:CPU1=${T2}C:WARN:Temperature(s) above maximum threshold of $TEMPTHRESHOLDHIGH C"
elif (( $TC >= $TEMPTHRESHOLDLOW && $TC < $TEMPTHRESHOLDHIGH )); then
    OFFSET=$(( ($TC - $TEMPTHRESHOLDLOW) * $GROWFACTOR ))
    OFFSETBASE16=$( printf "%x" $OFFSET )
    SPEEDSET=$(( $MINSPEED + $OFFSET ))
    SETBASE16=$( printf "%x" $SPEEDSET )
    echo "${OUT}CPU0=${T1}C:CPU1=${T2}C:SPEED=${SPEEDSET}%(0x${SETBASE16})"
    ipmitool raw 0x30 0x30 0x01 0x00 >/dev/null
    ipmitool raw 0x30 0x30 0x02 0xff 0x$SETBASE16 >/dev/null
else
    ipmitool raw 0x30 0x30 0x01 0x00 >/dev/null
    ipmitool raw 0x30 0x30 0x02 0xff 0x$MINSPEEDBASE16 >/dev/null
    echo "${OUT}CPU0=${T1}C:CPU1=${T2}C:LOWTEMP"
fi

#===REMOTE HOST Fan control===
for IP in "${HOSTS[@]}"; do
    T1=$(ipmitool sdr type temperature -I ${PROTOCOL} -H "${IP}" -U "${USERACCOUNT}" -P "${PASSWORD}" -y "${SOL_KEY}" | grep $SENSORNAME | cut -d"|" -f5 | cut -d" " -f2)
    T2=$(ipmitool sdr type temperature -I ${PROTOCOL} -H "${IP}" -U "${USERACCOUNT}" -P "${PASSWORD}" -y "${SOL_KEY}" | grep $SENSORNAME2 | cut -d"|" -f5 | cut -d" " -f2)
    if [[ -z $T1 || -z $T2 ]]; then
        TC=$TEMPTHRESHOLDHIGH
    elif (( $T1 > $T2 )); then
        TC=$T1
    else
        TC=$T2
    fi
    OUT="FAN-V3.0-${DATE}:${IP}:"
    #echo "${OUT}CPU0=${T1}C:CPU1=${T2}C"

    if (( $TC >= $TEMPTHRESHOLDHIGH )); then
        ipmitool raw 0x30 0x30 0x01 0x01 -I ${PROTOCOL} -H "${IP}" -U "${USERACCOUNT}" -P "${PASSWORD}" -y "${SOL_KEY}" >/dev/null
        echo "${OUT}CPU0=${T1}C:CPU1=${T2}C:WARN:Temperature(s) above maximum threshold of $TEMPTHRESHOLDHIGH C"
    elif (( $TC >= $TEMPTHRESHOLDLOW && $TC < $TEMPTHRESHOLDHIGH )); then
        OFFSET=$(( ($TC - $TEMPTHRESHOLDLOW) * $GROWFACTOR ))
        OFFSETBASE16=$( printf "%x" $OFFSET )
        SPEEDSET=$(( $MINSPEED + $OFFSET ))
        SETBASE16=$( printf "%x" $SPEEDSET )
        echo "${OUT}CPU0=${T1}C:CPU1=${T2}C:SPEED=${SPEEDSET}%(0x${SETBASE16})"
        ipmitool raw 0x30 0x30 0x01 0x00 -I ${PROTOCOL} -H "${IP}" -U "${USERACCOUNT}" -P "${PASSWORD}" -y "${SOL_KEY}" >/dev/null
        ipmitool raw 0x30 0x30 0x02 0xff -I ${PROTOCOL} -H "${IP}" -U "${USERACCOUNT}" -P "${PASSWORD}" -y "${SOL_KEY}" 0x$SETBASE16 >/dev/null
    else
        ipmitool raw 0x30 0x30 0x01 0x00 -I ${PROTOCOL} -H "${IP}" -U "${USERACCOUNT}" -P "${PASSWORD}" -y "${SOL_KEY}" >/dev/null
        ipmitool raw 0x30 0x30 0x02 0xff 0x$MINSPEEDBASE16 -I ${PROTOCOL} -H "${IP}" -U "${USERACCOUNT}" -P "${PASSWORD}" -y "${SOL_KEY}" >/dev/null
        echo "${OUT}CPU0=${T1}C:CPU1=${T2}C:LOWTEMP"
    fi
done
