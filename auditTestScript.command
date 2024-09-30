#!/bin/bash
echo '*************************************'
echo " Audit Script rev 2.5.1; May 2024 "
echo '*************************************'
#moves terminal window upper right corner
printf '\e[3;0;0t'
#resizes terminal to 100 x 50
printf '\e[8;60;100t'

printf '\033[1m'

#color definition
#call with: ${RED} curly brackets
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)
BOLD=$(tput bold)

#Calling Function to connect to wifi
source /Volumes/*/Audit_2/AuditTest/Network_Connect.sh

connect_to_wifi

# added "" to address
#curl -ls "https://support-sp.apple.com/sp/product?cc=$( ioreg -l | grep IOPlatformSerialNumber | awk '{print $4}' | sed 's|"||g' | cut -b9-13 )" | sed "s@.*<configCode>\(.*\)</configCode>.*@\1@"
#sleep 1
#reliabel way to determine year of Mac using plist. Deprecated curl command
#/usr/libexec/PlistBuddy -c "print :$(sysctl -n hw.model):_LOCALIZABLE_:marketingModel" /System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/en.lproj/SIMachineAttributes.plist
#/usr/libexec/PlistBuddy -c "print :'CPU Names':$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}' | cut -c 9-)-en-US_US" ~/Library/Preferences/com.apple.SystemProfiler.plist

echo

SN=$( ioreg -l | grep -i PlatformSerialNumber | cut -d "=" -f2 | cut -d '"' -f2 )

echo "Serial number: $SN"

echo

echo 'Device Model info'

system_profiler SPHardwareDataType | grep -E 'Model Name|Model Identifier|Processor Name|Processor Speed|Total Number of Cores|Memory'

echo

echo "MacOS Version: $(sw_vers -productVersion)"

echo

echo 'SSD/HDD info:'

# Get the list of internal disks
internalDisks=$(diskutil list | grep "internal" | awk '!/virtual/ { print $1 }')

# Convert the list of disks to an array
internalDisks=($internalDisks)

# Loop through each internal disk
for ((i=0; i<${#internalDisks[@]}; i++)); do
    disk=${internalDisks[$i]}
    # Get the disk info
    diskInfo=$(diskutil info "$disk")

    # Parse the disk info to get the size and SSD status
    diskSize=$(echo "$diskInfo" | grep -E "Disk Size:|Total Size:" | awk -F": " '{ print $2 }' | awk -F"(" '{ print $1 }' | tr -d '[:space:]')
    diskSSDStatus=$(echo "$diskInfo" | grep "Solid State:" | awk -F": " '{ print $2 }' | tr -d '[:space:]')

    # Determine the disk type
    if [ "$diskSSDStatus" == "Yes" ]; then
        diskType="SSD"
    else
        diskType="HDD"
    fi

    # Print the disk info 
    printf "\t%s" "Disk$i $diskSize $diskType"
    echo
    #echo -e "disk$i $diskSize $diskType"
done

echo

echo 'Graphics:'
M1=$(system_profiler SPDisplaysDataType 2> /dev/null | grep 'Chipset Model' | awk -F "Chipset Model:" '{print $2}' | cut -c 8)
#system_profiler SPDisplaysDataType 2> /dev/null | grep 'Chipset Model'
#system_profiler SPDisplaysDataType | grep -E 'Total Number of Cores'
if [[ "$M1" == "M" ]]; then
  echo -e "\tApple Silicon GPU"
  system_profiler SPDisplaysDataType | grep -E 'Chipset Model'
  system_profiler SPDisplaysDataType | grep -E 'Total Number of Cores'
else
  system_profiler SPDisplaysDataType | grep 'Chipset Model'
fi

USB=$(system_profiler SPUSBDataType 2> /dev/null | grep USB )
ThunderSpeed=$(system_profiler SPThunderboltDataType 2> /dev/null | grep Speed )

echo

echo "USB Port:"

if [[ $USB == *"USB 3.1 Bus"* ]]
then
    if [[ $M1 == "M" ]] 
    then
	echo -e "\tThunderbolt/USB 4.0 (USB C port)"
        echo -e "\tUse Thunderbolt/USB 4.0 configuration option"
    else
	echo -e "\tUSB3.1/Thunderbolt 3 (USB C port)"
        echo -e "\tUse Thunderbolt 3 configuration option"
    fi
elif [[ $USB == *"USB 3.0 Bus"* ]]
then
	echo -e "\tUSB 3.0 (Type A port)"

elif [[ $USB == *"USB 2.0 Bus"* ]]
then
	echo -e "\tUSB 2.0 (Type A port)"

fi


if [[ $ThunderSpeed == *"40"* ]]
then
    if [[ $M1 == "M" ]] 
    then
	    echo -e "\tThunderbolt 4"
    else
	    echo -e "\tThunderbolt 3"
    fi
elif [[ $ThunderSpeed == *"20"* ]]
then
	echo -e "\tThunderbolt 2"

elif [[ $ThunderSpeed == *"10"* ]]
then
	echo -e "\tThunderbolt 1"

fi

echo


#Check if battery is installed
BattInstalled=$(ioreg -l | grep -i BatteryInstalled)
if [[ $BattInstalled == *"Yes"* ]]
then
	echo -e 'Battery detected'

  #Checks Intel Battery Health
  SYS=$(system_profiler SPPowerDataType 2> /dev/null | grep -E "Cycle Count|Condition")
  #Check M1 Battery Health
  MBATT=$(system_profiler SPPowerDataType 2> /dev/null | grep -E "Health information|Cycle Count:|Condition:|Maximum Capacity")

  # Sets the variable to represent the current full charge capacity of the battery
  # Command breakdown: prints all of the information relating to power settings | finds the relevant line with battery capacity info | uses cut with delimiters to isolate just the full charge capacity | uses cut with delimiters to isolate just the numeric value of the full charge capacity | uses cut to remove any extra uneeded characters | uses sed to use only the first line of the output due to an issue with an extra serinal number being provided by some batteries
  FULL_CHARGE_CAPACITY=$(pmset -g everything | grep FCC | cut -d ";" -f4 | cut -d ":" -f2 |cut -c 6- | sed -n '1'p)

  # Sets the variable to represent the full charge capacity of the battery when it was designed
  # Command breakdown: prints all of the information relating to power settings | finds the relevant line with battery capacity info | uses cut with delimiters to isolate just the designed capacity | uses cut to remove any extra uneeded characters| uses sed to use only the first line of the output due to an issue with an extra serinal number being provided by some batteries
  DESIGN_CAPACITY=$(pmset -g everything | grep FCC | cut -d ";" -f5 | cut -c 9- | sed -n '1'p)

  # Divides the battery capacity variables to produce a floating point to represent the battery health. Scale=2 defines the accuracy, currently only bothers with 2 digits past the decimal point for this calculation
  BATTERY_DECIMAL=$(bc <<<"scale=2 ; $FULL_CHARGE_CAPACITY / $DESIGN_CAPACITY" 2> /dev/null)

  #echo -n 'Battery health percentage: '

  # Multiplies the resulting decimal value by 100 and removes the decimal point to convert it to an interger to to use as the battery health percentage
  BATTERY_HEALTH=$(echo $BATTERY_DECIMAL*100 | bc -l | cut -d "." -f1 2> /dev/null)

  #Checks if there is "Book" in Model Identifier to determine if unit is a MacBook or not and if not it will run battery health check
  IS_LAPTOP=$(system_profiler SPHardwareDataType | grep "Model Name" | grep "Book")

  if [[ "$IS_LAPTOP" == "" ]]
  then
    echo "Skipping Battery Check"
  else
    echo "Running Battery Check"
  fi

  #Evaluates the final battery percentage value, in cases where it is over 100%, it is printed as 100% to avoid confusion; otherwise the battery percentage is just printed.
  if [[ "$IS_LAPTOP" == "" ]]
  then
      BATTERY_HEALTH=null
  elif [ $BATTERY_HEALTH -gt 100 ]
  then
      BATTERY_HEALTH=100
  fi


  if [[ $M1 == "M" ]]
  then
    echo "$MBATT"
  else

    if echo "$SYS" | grep -q "Service Recommended"; then
      echo -e "${RED}$SYS${RESET}"
      printf '\033[1m'
    else 
      echo "$SYS"
    fi

    #echo $BATTERY_HEALTH%
    echo -n 'Battery health percentage: '
    if [ "$BATTERY_HEALTH" -lt 70 ]; then
      echo -e "${RED}$BATTERY_HEALTH%${RESET}"
    elif [ "$BATTERY_HEALTH" -lt 80 ]; then
      echo -e "${YELLOW}$BATTERY_HEALTH%${RESET}"
      echo -e "${BOLD}${YELLOW}Note: Apple units pass at 70% battery health, 80% for PowerON.${RESET}${RESET}"
    else
      echo -e "${GREEN}$BATTERY_HEALTH%${RESET}"
    fi

  fi
else
	echo -e "Battery not found"

fi


echo 


# set strings to bold after using RESET
printf '\033[1m'

# Retrieve information about Bluetooth devices
bluetooth_info=$(system_profiler SPBluetoothDataType 2>/dev/null)

# Check if any Bluetooth devices are detected
# Opens up bluetooth menu if devices are connected.
if echo "$bluetooth_info" | grep -q -E 'Connected:|Not Connected:|Devices (Paired, Configured, etc.):'; then
    echo -e "${RED}Bluetooth Devices Detected. Please remove any unwanted devices.${RESET}"
    osascript -e 'tell application "System Preferences" to activate' &
    osascript -e 'tell application "System Preferences" to reveal pane id "com.apple.preferences.Bluetooth"' >/dev/null 2>&1
    open -a "System Preferences" "x-apple.systempreferences:com.apple.preferences.Bluetooth"
    echo
fi

printf '\033[1m'

# Resets Apple Events permission, prevent error -1743
osascript_command='tell application "Finder"
set screenBounds to bounds of window of Desktop
set screenWidth to item 3 of screenBounds
set screenHeight to item 4 of screenBounds
end tell
tell application "Terminal"
set the position of the front window to {0, 0}
set the bounds of the front window to {0, 0, screenHeight * 0.5, screenHeight}
do script "/Volumes/*/Audit_2/AuditTest/mdmlockcheck.sh"
set the position of the front window to {screenHeight * 0.5, screenHeight * 0.32, screenHeight * .25, screenHeight}
set the bounds of the front window to {screenHeight * 0.5, screenHeight * 0.37, screenHeight * 1.25, screenHeight * 0.90}
do script "/Volumes/*/Audit_2/AuditTest/queryThisMac.sh"
set the position of the front window to {screenWidth * 0.45, screenHeight * 0.3, screenHeight * .25, screenHeight}
set the bounds of the front window to {screenHeight * 0.5, screenHeight * 0, screenHeight * 1.25, screenHeight * 0.32}
end tell'

# Execute the osascript command and capture the output
output=$(osascript -e "$osascript_command" 2>&1)

# Check if the specific error is in the output
if [[ $output == *"Not authorized to send Apple events to Finder. (-1743)"* ]]
then
    tccutil reset AppleEvents
    osascript -e "$osascript_command"
fi
#osascript -e 'tell application "System Preferences" to activate'
#osascript -e 'tell application "System Preferences" to reveal pane id "com.apple.preferences.Bluetooth"' >/dev/null 2>&1
#open -a "System Preferences" "x-apple.systempreferences:com.apple.preferences.Bluetooth"
#osascript -e "set Volume 4"; open -a "Safari" "http://test.poweron.com"
#open -a "Safari" "https://keyboardchecker.com"
#opens test site
#open -a "Safari" "http://test.poweron.com";
#osascript -e 'tell application "Terminal" to activate';
#exit 1;

#insert befoer end tell'
#do script "/Volumes/*/AuditTest/queryThisMac.sh"
#set the position of the front window to {screenWidth * 0.45, screenHeight * 0.3}
#set the bounds of the front window to {screenWidth * 0.366, 0, screenHeight * 1.25, screenHeight * 0.30}
