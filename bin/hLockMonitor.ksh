#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	29-Aug-2007
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="Lock Monitor [Mail Alert]"
hPageAlertTitle="Lock Monitor [Page Alert]"

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
#hUserID=""
hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1"`

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

# truncate temporary file

echo "Blocking SID\tSerial #\tUsername\tHostname\tProgram\tModule\tAction\tStatus\tLastCallET\tBlocked SID\tSerial #\tUsername\tHostname\tProgram\tModule\tAction\tStatus\tLastCallET" > $hTemporaryFile

hPageErrorCount=0
hMailErrorCount=0

#echo "$hSQLPlusOutput"|while read LINE;
cat "$hSQLPlusOutFile"|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		hBlockingSID=`GetColumnValue "$LINE" "1"`
		hBlockingSerialNo=`GetColumnValue "$LINE" "2"`
		hBlockingUsername=`GetColumnValue "$LINE" "3"`
		hBlockingHostname=`GetColumnValue "$LINE" "4"`
		hBlockingProgram=`GetColumnValue "$LINE" "5"`
		hBlockingModule=`GetColumnValue "$LINE" "6"`
		hBlockingAction=`GetColumnValue "$LINE" "7"`
		hBlockingStatus=`GetColumnValue "$LINE" "8"`
		hBlockingLastCallET=`GetColumnValue "$LINE" "9"`
		hBlockingSQL=`GetColumnValue "$LINE" "10"`
		hBlockedSID=`GetColumnValue "$LINE" "11"`
		hBlockedSerialNo=`GetColumnValue "$LINE" "12"`
		hBlockedUsername=`GetColumnValue "$LINE" "13"`
		hBlockedHostname=`GetColumnValue "$LINE" "14"`
		hBlockedProgram=`GetColumnValue "$LINE" "15"`
		hBlockedModule=`GetColumnValue "$LINE" "16"`
		hBlockedAction=`GetColumnValue "$LINE" "17"`
		hBlockedStatus=`GetColumnValue "$LINE" "18"`
		hBlockedLastCallET=`GetColumnValue "$LINE" "19"`
		hBlockedSQL=`GetColumnValue "$LINE" "20"`

		echo "$hBlockingSID\t$hBlockingSerialNo\t$hBlockingUsername\t$hBlockingHostname\t$hBlockingProgram\t$hBlockingModule\t$hBlockingAction\t$hBlockingStatus\t$hBlockingLastCallET\t$hBlockedSID\t$hBlockedSerialNo\t$hBlockedUsername\t$hBlockedHostname\t$hBlockedProgram\t$hBlockedModule\t$hBlockedAction\t$hBlockedStatus\t$hBlockedLastCallET" >> $hTemporaryFile
		echo "SQL<TD colspan=8><TEXT>$hBlockingSQL</TD>\tSQL<TD colspan=8><TEXT>$hBlockedSQL</TD>\t___SKIPLINE___" >> $hTemporaryFile
		hMailErrorCount=`expr $hMailErrorCount + 1`
	
	fi

done

if [ "$hMailErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle" "18"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`
	rm "$hTemporaryFile"
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

if [ -f "$hSQLPlusOutFile" ]; then
	rm $hSQLPlusOutFile
fi

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
