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

FUNCTION_LIST="/tmp/ifm.mk.functions_list.$$"
FUNCTIONS_FILE="/tmp/ifm.mk.functions.$$"
rm -f $FUNCTION_LIST $FUNCTIONS_FILE

function add_file() {
	local PERMS="$1"
	local SCRIPT="$2"
	local FILE="$3"
	local EXEC_FUNCTIONS="$4"
	echo ""
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
		grep "^##USE_FUNCTION" functions/$func | cut -f 2 -d " " | while read depen
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
#	add_files "" IFMMkDateFunctions IFMMkStringFunctions IFMMkListFunctions
fi

check_dependencies

cd functions
if [ $ALL_FUNCTIONS -eq 1 ]
then
	ls -1 > $FUNCTION_LIST
fi
HASH=$(sort $FUNCTION_LIST  | uniq | xargs cat | sha1sum | awk '{print $1}')
cd ..

cat >> $FUNCTIONS_FILE <<__EOF__ 
# https://github.com/ivanfmartinez/Mikrotik
# generated : $(date) 
# functions included = $(sort $FUNCTION_LIST | uniq | tr "\n" " ")

:global IFMMkFunctionsHash
# The functions will be defined again only if changed

if ("\$IFMMkFunctionsHash" != "$HASH") do={
        :global IFMMkFunctionsHash "$HASH"
__EOF__
sort $FUNCTION_LIST | uniq | while read func 
do
	echo "# $func " >> $FUNCTIONS_FILE
	cat functions/$func >> $FUNCTIONS_FILE
	echo "" >> $FUNCTIONS_FILE
done
cat >> $FUNCTIONS_FILE <<__EOF__ 

	if ([:len [/system script find name=IFMMkDefs]] = 1) do={
		/system script run IFMMkDefs
	}

}; 

__EOF__

add_file 'policy=read,write ' IFMMkFunctions $FUNCTIONS_FILE 0

rm -f $FUNCTIONS_FILE $FUNCTION_LIST