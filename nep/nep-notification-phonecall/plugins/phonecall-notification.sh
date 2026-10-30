#!/usr/bin/env bash
#
# Copyright (C) 2022 Wuerth Phoenix

export PATH=.:$PATH
logfile=/neteye/local/smsd/log/phone-call.log
tmpfile=/tmp/phonesend_email_tmp$$.txt
queuefile=/var/tmp/.phonequeue_$USER.txt
number=""
POPTS=""
trap 'rm -f $tmpfile; exit 1' 1 2 15
trap 'rm -f $tmpfile' 0

SMSBIN="smssend"

if [ -z "`which $SMSBIN`" ] ; then
  echo "$SMSBIN not found in \$PATH. Consider installing it."
  exit 1
fi

# Usage: phonecall-notification.sh <file|number>
#
#<file>: containing the list of recipients, one per line, in the international phone format (+XXxxxxxxx). #comments are ignored
#<number>: one phonenumber in the international phone format (+XXxxxxxxx)
#
## Functions
Usage() {
cat << EOF
Make a phonecall through the smstools daemon.

Required parameters:
  -r USERMOBILE (\$user.mobile\$)

Optional parameters:
  -t PHONE_TONE (\$phone_tone\$)

EOF
}

Help() {
  Usage;
  exit 0;
}

getqueue() {
    if [ -n "$QUEUES" ]
    then
        n=$(echo "$QUEUES" | tr -C -d ',' | wc -c)
        NQUEUE=$(expr $n + 1)
        if [ -e $queuefile ]
        then
            AQUEUE=$(cat $queuefile | tr -C -d "0123456789")
            if [ -z "$AQUEUE" ]
            then
                AQUEUE=0
            fi
        else
            AQUEUE=0
        fi
        AQUEUE=$(expr $AQUEUE + 1)
        if [ $AQUEUE -gt $NQUEUE ]
        then
            AQUEUE=1
        fi
        QSTR=$(echo "$QUEUES" | cut -d, -f$AQUEUE)
        POPTS="-q $QSTR"
        echo -n "$AQUEUE" >$queuefile
    fi
}

getphonenumber() {
    if [[ "$1" =~ ^\+[0-9]+$ ]]
    then
        number="$1"
    elif [[ "$1" =~ ^[0-9]+$ ]]
    then
        number="$1"
    elif [ -f "$PHONEBOOK" ]
    then
        if grep "$1" $PHONEBOOK | grep '+'
        then
            number=`grep "$1" $PHONEBOOK | head -1 | cut -d+ -f2`
        fi
    fi
    if [ -z "$number" ]
    then
        number="$1"
    fi
}

single_sendphone() {
    getphonenumber $1
    if [ -z "$DEBUG" ]
    then
        getqueue
        echo "`date`:$number" >>$logfile
        ff=$(mktemp -p $OUTGOINGDIR phone.XXXXXXXXXX)
        echo -e "To: $number\nVoicecall: yes\n\nTONE: $PHONE_TONE" >$ff
    else
        echo "`date`:$number:$text"
    fi
}

file_sendphone() {
    file=$1
    while read -r number comment
    do
        single_sendphone "$number"
    done <  $file
}

## Main
while getopts "hr:t:v" opt
do
  case "$opt" in
    h) Help ;;
    r) USERMOBILE=$OPTARG ;; # required
    t) PHONE_TONE=$OPTARG ;; # optional
    v) VERBOSE=$OPTARG ;;
   \?) echo "ERROR: Invalid option -$OPTARG" >&2
       Error ;;
    :) echo "Missing option argument for -$OPTARG" >&2
       Error ;;
    *) echo "Unimplemented option: -$OPTARG" >&2
       Error ;;
  esac
done

shift $((OPTIND - 1))

if [ -z "$USERMOBILE" ]; then
        echo 'Missing -r option required.' >&2
        exit 1
fi

if [ -z "$PHONE_TONE" ]; then
        echo 'Use default TONE.' >&2
        PHONE_TONE="TIME: 60 1,9,3,3,6,2,2,1,2,3,6"
fi

if [ $VERBOSE ]
then
    echo "ACTIVATING DEBUG MODE"
    DEBUG=1
    shift
fi

if [ -z "$PHONEBOOK" ]
then
    PHONEBOOK="$rdir/phonebook/phone"
fi
if [ -z "$OUTGOINGDIR" ]
then
    OUTGOINGDIR=/neteye/local/smsd/data/spool/outgoing
fi

param=`echo $USERMOBILE | sed -e 's/+//g'`
single_sendphone "$param"
#
# If special phonebook exists send to all recipients in that phonebook
#
#param=`echo $1 | sed -e 's/+//g'`
#if [ -f "${PHONEBOOK}_$param" ]
#then
#    file="${PHONEBOOK}_$param"
#    file_sendphone "$file"
#else
#    single_sendphone "$param"
#fi
