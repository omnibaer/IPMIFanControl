# IPMIFanControl
Fan Control script to override the built-in Dell IPMI fan control

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

IPMI Fan Control Override Script

DISCLAIMER: This has been tested on Dell R720 servers and some reports confirm that it works on other Dell servers. You need to test the ipmitool commands before implementing in your environment!

SETUP and USAGE:

crontab -l > mycron
echo "#" >> mycron
echo "# At every minute" >> mycron
echo "*/1 * * * * /bin/bash /scripts/dell_ipmi_fan_control.sh >> /tmp/cron.log" >> mycron
crontab mycron
rm mycron
chmod +x /scripts/dell_ipmi_fan_control.sh
