#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	20-Jul-2010
#	Updation Date:	
###############################################################

# define Alert Title
hMailAlertTitle="Profile Option Monitor [Mail Alert]"
hPageAlertTitle="Profile Option Monitor [Page Alert]"

# source the main environment file
hDirName=`dirname $0`
. $hDirName/hInitialize.ksh "$0"
if [ $? -eq 1 ]; then
	exit 1
fi

# source SQLPlus environment
. $hDirName/hInitializeSQLPlus.ksh
if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Unable to Load SQLPlus environment $hNewLine" "$hDateFormat"`
	exit 1
fi

# Read Script Specific Configuration Parameter
hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1" "True"`
hSendEMail=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SendEMail"`
hDataFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "DataFile" "True"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "DataFile: $hDataFile                          $hNewLine" "$hDateFormat"`

#run SQLPlus
hSQLPlusOutput=`RunSQLCommand "$hCredentials" "$hSQL1" "$hSQLPlusExecutable" "$hTemporaryFile"`

if [ $? -eq 1 ]; then

	`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	exit 1

fi

hMailErrorCount=0

while true
do

	if [ ! -f "$hDataFile.lock" ]; then
		touch "$hDataFile.lock"
		`WriteLogFile $hScriptLogFile "Acquired WRITE LOCK on $hDataFile $hNewLine" "$hDateFormat"`
		break
	else
		`WriteLogFile $hScriptLogFile "Waiting for the WRITE LOCK on $hDataFile $hNewLine" "$hDateFormat"`
		sleep 1
	fi
	
done

cat $hSQLPlusOutFile|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		hInstance=`GetColumnValue "$LINE" "1"`
		hProfileOptionName=`GetColumnValue "$LINE" "2"`
		hLevel=`GetColumnValue "$LINE" "3"`
		hLevelValue=`GetColumnValue "$LINE" "4"`
		hProfileOptionValue=`GetColumnValue "$LINE" "5"`
		hUpdateDate=`GetColumnValue "$LINE" "6"`
		hUpdatedBy=`GetColumnValue "$LINE" "7"`

		#if [ ! -f "$hDataFile" ]; then
		if [ $hMailErrorCount -eq 0 ]; then
			printf "___TABLE___\t7\t$hInstance\n" >> $hDataFile
			printf "Instance\tProfileOptionName\tLevel\tLevel Value\tProfileOptionValue\tUpdated\tUpdatedBy\n" >> $hDataFile
		fi
		
		#if [ $hMailErrorCount -eq 0 ]; then
		#	printf "Instance:<TD colspan=6>$hInstance</TD>\t___SKIPLINE___\n" >> $hDataFile
		#fi
		printf "$hInstance\t$hProfileOptionName\t$hLevel\t$hLevelValue\t$hProfileOptionValue\t$hUpdateDate\t$hUpdatedBy\n" >> $hDataFile

		hMailErrorCount=`expr $hMailErrorCount + 1`
		
	fi
	
done

chmod -f 777 "$hDataFile"
cp "$hDataFile" "$hTemporaryFile"

rm "$hDataFile.lock"

if [ -f $hSQLPlusOutFile ]; then
	rm $hSQLPlusOutFile
fi

if [ "$hSendEMail" = "True" ]; then

	if [ "$hMailErrorCount" -gt 0 ]; then
		`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle [Count=$hMailErrorCount]" "7"` 
		`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
	else
		`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`
		rm "$hTemporaryFile"
	fi
	
	if [ -f "$hDataFile" ]; then
		rm "$hDataFile"
	fi

fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
