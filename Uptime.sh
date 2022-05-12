#!/bin/zsh


# Script designed to remind users to reboot their device after it has been running for over 14 days.
# Utilizes Bart Reardon's Swift Dialog application.
# Combines a launch agent to prompt every 30 minutes.

# -----------------------------------------------------------------------------------------------------------------------------------------------------
# *** CUSTOM PORTION OF THE SCRIPT ***
# -----------------------------------------------------------------------------------------------------------------------------------------------------


# Initial SwiftDialog starting arguments. Title and message set by admin
title="Please Restart Your Computer"

message="Your computer has detected that its current uptime has exceeded 14 days. \n \n
In order to maintain proper operation  \nplease press the 'Restart' button after saving your work. \n \n
If now is not a good time you may exit this prompt by clicking 'Try Again in 30 Minutes', but you will continue to receive alerts until restart your computer."


# Icon filepath. Either use a generic Enable file, or a logo for the organization.
icon="/Path/to/your/file"

# Number of days the computer can be on before users start being prompted to reboot.
set_limit=14


# -----------------------------------------------------------------------------------------------------------------------------------------------------
# *** VARIABLES ***
# -----------------------------------------------------------------------------------------------------------------------------------------------------


# Variables for locations Dialog (for launching the app), and command file (write to that file to set what the app shows)
dialogApp="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"


# Create the filepath for the Uptime log as variable and create the file
uptime_log="/private/var/tmp/Uptime.log"
touch "$uptime_log"


# What we're righting to the command file to control the app
dialogCMD="$dialogApp -o --title \"$title\" \
--position \"center\" \
--message \"$message\" \
--centericon \
--width \"57%\" \
--height \"46%\" \
--alignment \"center\" \
--titlefont \"weight=regular,size=36,color=#244A86\" \
--messagefont \"weight=thin,size=22\" \
--icon \"$icon\" \
--button1text \"Restart\" \
--button1shellaction \"/bin/echo Continue > $uptime_log\" \
--button2text \"Try Again in 30 Minutes\" \
"


# -----------------------------------------------------------------------------------------------------------------------------------------------------
# *** FUNCTIONS ***
# -----------------------------------------------------------------------------------------------------------------------------------------------------


# Execute a SwiftDialog command by writing to its command file to make updates to an open window.
function dialog_command(){
	echo "$1"
	echo "$1"  >> "$dialog_command_file"
}


# Clear out the SwiftDialog command file. Used at beginning of every run of the script.
function refresh_dialog_command_file(){
	rm "$dialog_command_file"
	touch "$dialog_command_file"
}


# Create Uptime log and write the system uptime to it.
function refresh_uptime_log(){
	rm "$uptime_log"
	touch "$uptime_log"
	uptime > "$uptime_log"
}


# -----------------------------------------------------------------------------------------------------------------------------------------------------
# *** MAKE SURE SWIFTDIALOG GETS INSTALLED ***
# -----------------------------------------------------------------------------------------------------------------------------------------------------


# Setting variables to detect whether Installomator and SwiftDialog are currently installed or not.
installomator="/usr/local/Installomator/Installomator.sh"
dialogApp="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"



# Check for Swift Dialog. If it doesn't exist then install Installomator, update it, and install SwiftDialog.

if [[ -e "$dialogApp" ]];
	then echo "SwiftDialog in place. Not continuing install"
	else curl -L -o /tmp/Installomator.pkg "https://github.com/Installomator/Installomator/releases/download/v9.0.1/Installomator-9.0.1.pkg"
		installer -pkg /tmp/Installomator.pkg -target /
		"$installomator" installomator NOTIFY=silent
		"$installomator" swiftdialog NOTIFY=silent
fi



# --------------------------------------------------------------------------------------------------------------------------------------------------------------
# *** CHECK WE'RE IN USER ENVIRONMENT ***
# --------------------------------------------------------------------------------------------------------------------------------------------------------------


# Check that user is logged in currently.
setupAssistantProcess=$(pgrep -l "Setup Assistant")
until [ "$setupAssistantProcess" = "" ]; do
  echo "$(date "+%a %h %d %H:%M:%S"): Setup Assistant Still Running. PID $setupAssistantProcess." 2>&1 | tee -a /var/tmp/deploy.log
  sleep 1
  setupAssistantProcess=$(pgrep -l "Setup Assistant")
done
echo "$(date "+%a %h %d %H:%M:%S"): Out of Setup Assistant" 2>&1 | tee -a /var/tmp/deploy.log
echo "$(date "+%a %h %d %H:%M:%S"): Logged in user is $(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')" 2>&1 | tee -a /var/tmp/deploy.log

finderProcess=$(pgrep -l "Finder")
until [ "$finderProcess" != "" ]; do
  echo "$(date "+%a %h %d %H:%M:%S"): Finder process not found. Assuming device is at login screen. PID $finderProcess" 2>&1 | tee -a /var/tmp/deploy.log
  sleep 1
  finderProcess=$(pgrep -l "Finder")
done
echo "$(date "+%a %h %d %H:%M:%S"): Finder is running" 2>&1 | tee -a /var/tmp/deploy.log
echo "$(date "+%a %h %d %H:%M:%S"): Logged in user is $(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')" 2>&1 | tee -a /var/tmp/deploy.log



# -----------------------------------------------------------------------------------------------------------------------------------------------------
# *** START RUNNING COMMANDS AND ACTIONS ***
# -----------------------------------------------------------------------------------------------------------------------------------------------------


# Create Uptime log and write the system uptime to it. Used to refresh log so that it doesn't expand in size indefinitely, or prevent "awk" from working. 
refresh_uptime_log


# Clear out the SwiftDialog command file. Used at beginning of every run of the script.
refresh_dialog_command_file


# Determine number of days the computer has been up. 
days=$(sudo awk -F'(up | days,)' '{print $2}' $uptime_log)
echo "$days"



# If computer has been on longer than the allowed limit start up the prompt for user to restart.
if (( $days > $set_limit )); then  
	/bin/echo "$dialogCMD"
	eval "$dialogCMD"
	sleep 0.1

# Assign variable to verify user wants reboot. The "Continue" is only echoed to the command file if the user clicks button 1, and thus won't be able to be grep'ed if they cancel. 
	Restart=$(grep "Continue" $uptime_log)

	if [[ $Restart == "Continue" ]]; then 


# Refresh the Dialog command file to create new Dialog prompt for user to confirm restart action.
		refresh_dialog_command_file
		sleep 0.1
        dialogCMD="$dialogApp -o --title \"Confirm\" \
		--position \"center\" \
		--message \"Please verify that all of your work is saved prior to restarting.\" \
		--centericon \
		--icon \"$icon\" \
		--width \"40%\" \
		--height \"27%\" \
		--alignment \"center\" \
		--titlefont \"weight=regular,size=36,color=#244A86\" \
		--messagefont \"weight=thin,size=22\" \
		--button1text \"Confirm Restart\" \
		--button1shellaction \"/bin/echo Confirm > $uptime_log\" \
		--button2text \"Cancel\" \
		"
		/bin/echo "$dialogCMD"
		eval "$dialogCMD"
		sleep 0.1


# Assign variable to verify user is confirming they are ready to reboot. The "Confirm" is only echoed to the command file if the user clicks button 1 and thus won't be able to be grep'ed if they cancel.
		Restart=$(grep "Confirm" $uptime_log)
        if [[ $Restart == "Confirm" ]]; then
        	sudo shutdown -r now
        	exit 0
        else 
        	exit 1
        fi


    else
        exit 2
    fi


else 
	exit 5
fi

# -----------------------------------------------------------------------------------------------------------------------------------------------------
# *** END OF SCRIPT ***
# -----------------------------------------------------------------------------------------------------------------------------------------------------
exit 10
