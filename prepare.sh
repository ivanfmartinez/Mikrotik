#!/bin/bash

#
# Prepare function files to be "pasted" on mikrotik console or executed as script
#

ALL_FUNCTIONS=0
if [ "$1" = "-all" ]
then
	ALL_FUNCTIONS=1
	shift
fi

FUNCTIONS_DIR="functions"
TMP_FUNCTIONS_DIR="/tmp/ifm.mk.functions.d.$$"
#TODO accept extra functions directories....
if [ "$EXTRA_FUNCTIONS_DIRS" != "" ]
then
	rm -Rf $TMP_FUNCTIONS_DIR
	mkdir -p $TMP_FUNCTIONS_DIR
	for dir in $FUNCTIONS_DIR $EXTRA_FUNCTIONS_DIRS
	do
		if [ -d $dir ]
		then
			cp $dir/* $TMP_FUNCTIONS_DIR
		fi
	done
	FUNCTIONS_DIR=$TMP_FUNCTIONS_DIR
fi

FUNCTION_LIST="/tmp/ifm.mk.functions_list.$$"
FUNCTIONS_FILE="/tmp/ifm.mk.functions.$$"
rm -f $FUNCTION_LIST $FUNCTIONS_FILE

function add_file() {
	local PERMS="$1"
	local SCRIPT="$2"
	local FILE="$3"
	local EXEC_FUNCTIONS="$4"
	echo ""
	echo ":put \"adding file $SCRIPT\""
	echo ":do {/system script add name="$SCRIPT"} on-error={}"
	echo -n "/system script set "$SCRIPT" $PERMS source=\""
	if [ "$EXEC_FUNCTIONS" = "1" ]
	then
		echo -n "/system script run IFMMkFunctions\n" 
	fi
	grep "^##USE_FUNCTION" ${FILE} | cut -f 2 -d " " >> $FUNCTION_LIST
	cat $FILE | sed -e 's/\(["\$?]\)/\\\1/g' | sed -e 's/$/\\n/' | sed -e 's/##USE_FUNCTION/:global/' | tr -d '\n'
	echo "\""	
}

function add_files() {
	local PERMS="$1"
	shift
	for fn in $*
	do
		if [ -f $fn ]
		then
			add_file "$PERMS" $fn $fn
		else
			echo "# $fn not found"
		fi
	done
}

function check_dependencies() {
	local CNT_START=$(cat $FUNCTION_LIST | wc -l)
	sort $FUNCTION_LIST | uniq | while read func
	do
		grep "^##USE_FUNCTION" ${FUNCTIONS_DIR}/$func | cut -f 2 -d " " | while read depen
		do
			grep -q "^$depen\$" $FUNCTION_LIST
			if [ $? -ne 0 ]
			then
				echo "$depen" >> $FUNCTION_LIST
			fi
		done
	done
	local CNT_END=$(cat $FUNCTION_LIST | wc -l)
	if [ $CNT_START -ne $CNT_END ]
	then
		check_dependencies
	fi
	
}


if [ "$1" != "" ]
then
	add_files "" $*
else
	add_file "policy=read,write,sensitive,test,password,policy" IFMMkBackup scripts/IFMMkBackup 1
	add_file "policy=read,write,sensitive,test,password,policy" IFMMkStats scripts/IFMMkStats 1
	add_file "policy=read,write,sensitive,test,password,policy" IFMCheckNetwatch scripts/IFMCheckNetwatch 0
fi


if [ $ALL_FUNCTIONS -ne 1 ]
then
	check_dependencies
fi

cd $FUNCTIONS_DIR
if [ $ALL_FUNCTIONS -eq 1 ]
then
	ls -1  > $FUNCTION_LIST
fi
HASH=$(sort $FUNCTION_LIST | grep -E -i "^[a-z0-9]+\$" | uniq | xargs cat | sha1sum | awk '{print $1}')
cd ..

cat >> $FUNCTIONS_FILE  <<__EOF__ 
# https://github.com/ivanfmartinez/Mikrotik
# generated : $(date) 
# functions included = $(sort $FUNCTION_LIST | uniq | tr "\n" " ")

:global IFMMkFunctionsHash
# The functions will be defined again only if changed

if ("\$IFMMkFunctionsHash" != "$HASH") do={
        :global IFMMkFunctionsHash "$HASH"
        :log info "loading IFMMkFunctions definitions"
__EOF__

sort $FUNCTION_LIST | grep -E -i "^[a-z0-9]+\$" | uniq | while read func 
do
	echo "# $func " >> $FUNCTIONS_FILE
	cat ${FUNCTIONS_DIR}/$func >> $FUNCTIONS_FILE
	echo "" >> $FUNCTIONS_FILE
done

cat >> $FUNCTIONS_FILE <<__EOF__ 

	if ([:len [/system script find name=IFMMkDefs]] = 1) do={
		/system script run IFMMkDefs
	}

}; 

__EOF__

add_file 'policy=read,write,test ' IFMMkFunctions $FUNCTIONS_FILE 0

cat <<__EOF__

:put "Adding schedulers"
# Automaticaly load functions on startup
/system scheduler add name=IFMMkFunctions    start-time=startup 		on-event="/system script run IFMMkFunctions" policy=read,write,test,policy
/system scheduler add name=IFMMkBackup       start-time=02:00:00 interval=1w 	on-event="/system script run IFMMkBackup" policy=read,write,password,sensitive,test,policy
/system scheduler add name=IFMCheckNetwatch  start-time=02:00:00 interval=5m 	on-event="/system script run IFMCheckNetwatch" policy=read,write,password,sensitive,test,policy

:put "Executing IFMMkFunctions"
/system script run IFMMkFunctions

__EOF__

rm -f $FUNCTIONS_FILE $FUNCTION_LIST 
rm -Rf $TMP_FUNCTIONS_DIR
