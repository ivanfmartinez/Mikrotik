#!/bin/bash
if [ ! -f deploy/install.rsc ]
then
	mkdir -p deploy
	bash ./prepare.sh -all > deploy/install.rsc
fi

while [ "$1" != "" ]
do
	ssh $1 < deploy/install.rsc 
	shift
done
