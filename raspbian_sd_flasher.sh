#!/bin/bash

# Raspbian SD Flasher
# Copyright (C) 2014  Christopher Kyle Horton
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


#=============================================================================
# Variable declarations
#=============================================================================

TITLE="Raspbian SD Flasher"
URL="http://downloads.raspberrypi.org/raspbian/images/raspbian-2014-09-12/2014-09-09-wheezy-raspbian.zip"
FILENAME="2014-09-09-wheezy-raspbian.zip"
HOMEPATH=`eval echo ~$USER`
DOWNLOADFOLDER="$HOMEPATH/Downloads"
FILEPATH="$DOWNLOADFOLDER/$FILENAME"
IMAGEFILE="2014-09-09-wheezy-raspbian.img"
SHASUM="951a9092dd160ea06195963d1afb47220588ed84"

trap "exit 1" TERM
export TOP_PID=$$

#=============================================================================
# Function definitions
#=============================================================================

abort_script() { kill -s TERM $TOP_PID ; }

setup_fail()
{
	if [ $# == 1 ]
	then
		TEXT="$1"
	else
		TEXT="$TITLE failed (unknown error)."
	fi
	TEXT="$TEXT Please re-run this script."
	zenity --error --title="$TITLE" --text="$TEXT"
	abort_script
}

show_message()
{
	zenity --info --title="$TITLE" --text="$1"
}

#=============================================================================
# Main script
#=============================================================================

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
	echo "You must be root to run $TITLE."
	exit 1
fi

# Check user has zenity installed
if ! command -v zenity >/dev/null; then
	echo "You must install zenity to use $TITLE."
	exit 1
fi

# Check user has mkdosfs installed
if ! command -v mkdosfs >/dev/null; then
	setup_fail "You need mkdosfs to use $TITLE. Try installing the dosfstools package."
fi

# Download Raspbian .zip archive
if zenity --question --title="$TITLE" --text="Would you like to download a fresh Raspbian image?"
then
	cd $DOWNLOADFOLDER
	rm -f $FILENAME
	wget $URL 2>&1 | sed -u "s/.* \([0-9]\+%\)\ \+\([0-9.]\+.\) \(.*\)/\1\n# Downloading $FILENAME at \2\/s, ETA \3/" | zenity --progress --title="$TITLE" --auto-close
	sha1sum $FILENAME | grep $SHASUM
	if [ $? -ne 0 ]
	then
		setup_fail "Download SHA1 does not match. Try again."
	fi
	show_message "Download complete."
else
	if [ -e "$FILEPATH" ]
	then
		echo "$FILEPATH confirmed to exist; continuing."
	else
		setup_fail "Cannot continue since there is no downloaded .zip archive."
	fi
fi

# Get SD card info
df -h | grep '/dev/sd\|/dev/mmcblk'
show_message "Insert your SD card, then click OK. Check the terminal for df -h output. (You may have to manually mount the SD card in your file manager to see it appear.)"
df -h | grep '/dev/sd\|/dev/mmcblk'
SDDEVICE=`zenity --entry \
--title="$TITLE" \
--text="Enter the device for your SD card (i.e. /dev/sdd or /dev/mmcblk0):"`
case $? in
	1)
		setup_fail "Cannot continue without device."
		;;
	-1)
		setup_fail
		;;
esac
umount ${SDDEVICE}?*

# Unzip downloaded file
cd ~/Downloads
if [ ! -e $IMAGEFILE ]
then
	(unzip $FILENAME) | zenity --progress --title="$TITLE" --text="Unzipping $FILENAME..." --auto-close --pulsate
fi

# Write image to SD card
if zenity --question --title="$TITLE" --text="The image file $IMAGEFILE will now be flashed onto $SDDEVICE . This could take a while. Proceed?"
then
	echo "Proceeding..."
else
	setup_fail "Flashing cancelled."
fi
(sudo mkdosfs -F 32 -v $SDDEVICE -I) | zenity --progress --title="$TITLE" --text="Formatting $SDDEVICE in FAT 32 filesystem..." --auto-close --pulsate
(sudo dd bs=4M if=$IMAGEFILE of=$SDDEVICE) | zenity --progress --title="$TITLE" --text="Flashing $IMAGEFILE onto $SDDEVICE..." --auto-close --pulsate
echo "Running sync..."
sync
echo "Ejecting $SDDEVICE..."
sudo eject $SDDEVICE
show_message "Flashing complete! Please remove the SD card now."