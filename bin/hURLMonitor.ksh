#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	12-Dec-2009
#	Updation Date:	12-Dec-2009
#	Updation Date:	12-Dec-2009
###############################################################

# define Alert Title
hMailAlertTitle="URL Monitor [Mail Alert]"
hPageAlertTitle="URL Monitor [Page Alert]"

# source the main environment file
hDirName=`dirname $0`
. $hDirName/hInitialize.ksh "$0"
if [ $? -eq 1 ]; then
	exit 1
fi

# Read Script Specific Configuration Parameter
hTemporaryFile1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "TemporaryFile1" "True"`
hURLList=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "URLList" "True"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "URLList:          $hURLList                 $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

# truncate temporary file
echo "Serial #\tName\tURL\tStatus\tOutput" > $hTemporaryFile

hPageErrorCount=0
hSRNo=1
CLASSPATH=$hDirName:$CLASSPATH ; export CLASSPATH

# Check if the URLList is configured
if [ ! -f "$hURLList" ]; then
	`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "FILE: $hURLList is not configured" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "FILE: $hURLList is NOT configured"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
fi
hTotalURLs=`wc -l $hURLList`

cat "$hURLList"|while read LINE;
do
	if [ -z "$LINE" ]; then
		continue;
	fi

	hName=`GetColumnValue "$LINE" "1"`
	hURL=`GetColumnValue "$LINE" "2"`

	# if the line is commented, please ignore it
	if [ `echo "$hName"|cut -c1` = "#" ]; then
		echo ".\t$hName\t$hURL\tIgnored\tURL is commented out in config file" >> $hTemporaryFile
		`WriteLogFile $hScriptLogFile "Success $hNewLine" "$hDateFormat"`
		continue
	fi
	
	`WriteLogFile $hScriptLogFile "Checking ***$hSRNo of $hTotalURLs*** [$hName]:[$hURL] . . . . . $hNewLine" "$hDateFormat"`
	
	hOutput=`java -cp $CLASSPATH hURLCheck $hURL 2>$hTemporaryFile1`
	echo "$hOutput" >> $hTemporaryFile1
	#hOutput="`expand $hTemporaryFile1|tail -1`"
	hOutput="`sed -e 's/	/<br>/' $hTemporaryFile1 |tr -d '\n'`"
	hOutput2="`cat $hTemporaryFile1"

	hResponse=`echo $hOutput | awk '{print $2}'`
	if [ "$hResponse" = "200" -o "$hResponse" = "301"  -o "$hResponse" = "302" ]; then
		echo "$hSRNo\t$hName\t$hURL\tSuccess [$hResponse]\t$hOutput" >> $hTemporaryFile
		`WriteLogFile $hScriptLogFile "Success $hNewLine" "$hDateFormat"`
    elif [ "$hResponse" = "500" ]; then
		echo "$hSRNo\t$hName\t$hURL\tFailure [$hResponse]\t$hOutput" >> $hTemporaryFile
		`WriteLogFile $hScriptLogFile "Failed $hNewLine $hOutput2" "$hDateFormat"`
		hPageErrorCount=`expr $hPageErrorCount + 1`
	else
		echo "$hSRNo\t$hName\t$hURL\tFailure [$hResponse]\t$hOutput" >> $hTemporaryFile
		`WriteLogFile $hScriptLogFile "Failed $hNewLine $hOutput2" "$hDateFormat"`
		hPageErrorCount=`expr $hPageErrorCount + 1`
	fi
	hSRNo=`expr $hSRNo + 1`

done

if [ "$hPageErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Page to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject FAILEDCount=$hPageErrorCount" "$hPageAlertTitle <br> $hPageErrorCount [Failed] out of $hTotalURLs" "5"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat"`
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

if [ -f "$hTemporaryFile" ]; then
	rm "$hTemporaryFile"
fi

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
