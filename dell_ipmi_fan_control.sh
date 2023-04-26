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
# echo "*/1 * * * * /bin/bash /scripts/dell_ipmi_fan_control.sh >> /tmp/cron.log" >> mycron
# crontab mycron
# rm mycron
# chmod +x /scripts/dell_ipmi_fan_control.sh
#
#SCRIPT START
DATE=$(date +%Y-%m-%d-%H%M%S)
echo "Fan Controller----------------------------V1.4"
echo "$DATE"
#
MINSPEED=25 #the minimum fan speed as a percent
GROWFACTOR=2 #the fan percent to increase by per degree
MINSPEEDBASE16=19 #the minimum speed in BASE16
#sensor IDs. To find the correct IDs for your system, run: impitool sdr type temperature
SENSORNAME="0Eh"
SENSORNAME2="0Fh"
#low and high temperature thresholds in degrees celsius. Fan speeds will scale based on these values
TEMPTHRESHOLDLOW=45
TEMPTHRESHOLDHIGH=70
#emergency temperature threshold in degrees celsius. At this temp, full fan control is returned to IPMI
EMERGTHRESHOLD=70
#
#Detect and display CPU temperatures
T1=$(ipmitool sdr type temperature | grep $SENSORNAME | cut -d"|" -f5 | cut -d" " -f2)
T2=$(ipmitool sdr type temperature | grep $SENSORNAME2 | cut -d"|" -f5 | cut -d" " -f2)
if [[ $T1 > $T2 ]]; then 
    TC=$T1
else
    TC=$T2
fi
echo "CPU0: $T1 C"
echo "CPU1: $T2 C"
#
#Test temperatures
if (($TC >= $EMERGTHRESHOLD)); then
    #Temperature over emergency threshold, full fan control is returned to IPMI
    echo "WARN: Temperature(s) above emergency threshold of $EMERGTHRESHOLD C"
    ipmitool raw 0x30 0x30 0x01 0x01
elif (($TC >= $TEMPTHRESHOLDLOW && $TC < $TEMPTHRESHOLDHIGH)); then
    #temperature is in the scaling range, calculate the offset and set the fan speed
    #offset is = ([highest temp] - [low threshold]) * [growth factor]
    OFFSET=$(( ($TC - $TEMPTHRESHOLDLOW) * $GROWFACTOR ))
    OFFSETBASE16=$( printf "%x" $OFFSET )
    SPEEDSET=$(( $MINSPEED + $OFFSET ))
    SETBASE16=$( printf "%x" $SPEEDSET )
    echo "Setting static fan speed to $SPEEDSET% (0x$SETBASE16)"
    ipmitool raw 0x30 0x30 0x01 0x00
    ipmitool raw 0x30 0x30 0x02 0xff 0x$SETBASE16
else
    #temperature is below the scaling range, set fan speed to minimum
    echo "In low range..."
    ipmitool raw 0x30 0x30 0x01 0x00
    ipmitool raw 0x30 0x30 0x02 0xff 0x$MINSPEEDBASE16
fi
#END SCRIPT
