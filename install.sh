#!/bin/bash
# 1 - CONNECT to device after upload
CONNECT=${CONNECT:-0}
BACKUP=${BACKUP:-0}
FORCE=0
if [ "$1" = "FORCE" ]
then
	shift
	FORCE=1
fi

while [ "$1" != "" ]
do

        # Some older 6.x versions use system as package, newer have system and routeros
        # 7.x have only routeros
        MK_VERSION=$(/usr/bin/ssh "$1" ":put [/system package get routeros version]" | grep -E -o "^[0-9]+")
        if [ "$MK_VERSION" = "" ]
        then
            MK_VERSION=$(/usr/bin/ssh "$1" ":put [/system package get system version]" | grep -E -o "^[0-9]+")
        fi
        if [ "$MK_VERSION" = "" ]
        then
        	echo "Unable to detect version for $1"
        	exit
        fi

        export MK_VERSION

        if [ $FORCE -eq 1 ]
        then
            rm -f deploy/install_V${MK_VERSION}.rsc
        fi
        if [ ! -f deploy/install_V${MK_VERSION}.rsc ]
        then
        	mkdir -p deploy
		bash ./prepare.sh -all -fn deploy/IFMMkFunctions_V${MK_VERSION} > deploy/install_V${MK_VERSION}.rsc
	fi

	ssh $1 < deploy/install_V${MK_VERSION}.rsc 
	if [ "$BACKUP" = "1" ]
	then
		echo "Executing backup"
		ssh $1 "/system script run IFMMkBackup; /file print"
	fi
	if [ "$CONNECT" = "1" ]
	then
		ssh $1
	fi
	shift
done
