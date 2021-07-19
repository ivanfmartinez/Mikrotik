#!/bin/bash
# 1 - CONNECT to device after upload
CONNECT=${CONNECT:-0}
BACKUP=${BACKUP:-0}
if [ "$1" = "FORCE" ]
then
	shift
	rm -f deploy/install.rsc
fi
if [ ! -f deploy/install.rsc ]
then
	mkdir -p deploy
	bash ./prepare.sh -all -fn deploy/IFMMkFunctions > deploy/install.rsc
fi

while [ "$1" != "" ]
do
	ssh $1 < deploy/install.rsc 
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
