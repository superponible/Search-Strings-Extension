#!/bin/bash

# Written by: Dave Lassalle
# A wrapper around srch_strings.  This can be used in place of srch_strings,
#   and will forward all command line options to srch_strings.  If -b
#   is specified and the proper srch_strings args were given, it will
#   add block number and byte offset within the block to the output of
#   srch_strings.

AWK_CMD="/usr/bin/awk"
BC_CMD="/usr/bin/bc"
PASTE_CMD="/usr/bin/paste"
RM_CMD="/bin/rm"
SS_CMD="/usr/local/bin/srch_strings"
CUT_CMD="/usr/bin/cut"
BLKSTAT_CMD="/usr/local/bin/blkstat"

usage()
{
cat << EOF
usage: $0 [-h] [-b blocksize] [other srch_strings options] [file(s)]

$0 is a wrapper for the srch_strings command and can be used in its place.
	$0 adds the -b argument which is the block size, if it is known.
	If the -b and "-t d" are not given, this script simply passes the
	options to srch_strngs.

OPTIONS:
   -h      Print this help message
   -b      block size of filesystem in imagefile(s)

Usage: srch_strings [option(s)] [file(s)]
 Display printable strings in [file(s)] (stdin by default)
 The options are:
  -a -                 Scan the entire file, not just the data section
  -f       Print the name of the file before each string
  -n number       Locate & print any NUL-terminated sequence of at
  -<number>                 least [number] characters (default 4).
  -t {o,x,d}        Print the location of the string in base 8, 10 or 16
  -o                        An alias for --radix=o
  -e {s,S,b,l,B,L} Select character size and endianness:
                            s = 7-bit, S = 8-bit, {b,l} = 16-bit, {B,L} = 32-bit
  -h                  Display this information
  -v               Print the program's version number


EOF
}

ORIG_ARGS=$@
BLOCKSIZE=
LOCATION=
LISTFILE=0
while getopts “:hb:afn:ot:e:v” OPTION; do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         b)
             BLOCKSIZE=$OPTARG
             ;;
	 t)
	     LOCATION=$OPTARG
	     ;;
	 f)
	     LISTFILE=1
	     ;;
         \?)
             usage
             exit 1
             ;;
	 :)
	     echo "Option -$OPTARG requires an argument." >&2
	     exit 1
	     ;;
     esac
done

if [[ -z $BLOCKSIZE ]] 
then
		$SS_CMD $@
else
	if [[ $LOCATION != "d" ]]
	then
		echo "Must use \"-t d\" with -b option."
		usage
		exit 1
	else
		# Get argument list without -b
		SS_ARGS=
		SKIP=
		for var in "$@"
		do
			if [ $var == "-b" ]
			then
				SKIP=1
			elif [ "$SKIP" == "1" ]
			then
				SKIP=0
			else
				SS_ARGS="$SS_ARGS $var"
			fi
		done
		$SS_CMD $SS_ARGS > srch_strings.tmp
		if [ $LISTFILE -eq 0 ]
		then
			$AWK_CMD '{print $1"/'$BLOCKSIZE'"}' srch_strings.tmp | $BC_CMD > srch_blocks.tmp 
			$AWK_CMD '{print $1%'$BLOCKSIZE'}' srch_strings.tmp | $BC_CMD > srch_offset.tmp 
			$PASTE_CMD srch_blocks.tmp srch_offset.tmp | $PASTE_CMD - srch_strings.tmp 
		else
			$AWK_CMD -F: '{print $1":"}' srch_strings.tmp > srch_strings1.tmp
			$CUT_CMD -d':' -f2- srch_strings.tmp > srch_strings2.tmp
			$AWK_CMD '{print $1"/'$BLOCKSIZE'"}' srch_strings2.tmp | $BC_CMD > srch_blocks.tmp 
			$AWK_CMD '{print $1%'$BLOCKSIZE'}' srch_strings2.tmp | $BC_CMD > srch_offset.tmp 
			$PASTE_CMD srch_strings1.tmp srch_blocks.tmp | $PASTE_CMD - srch_offset.tmp | $PASTE_CMD - srch_strings2.tmp 
			$RM_CMD srch_strings1.tmp
			$RM_CMD srch_strings2.tmp
		fi
		#$RM_CMD srch_blocks.tmp
		$RM_CMD srch_offset.tmp
		$RM_CMD srch_strings.tmp
		exit 0
	fi
fi

exit 0
