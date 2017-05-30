#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	09-Sep-2008
#	Updation Date:	09-Sep-2008
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="DB Session Monitor [Mail Alert]"
hPageAlertTitle="DB Session Monitor [Page Alert]"

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
hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1"`
hIdleTimeInSeconds=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "IdleTimeInSeconds"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "IdleTimeInSeconds: $hIdleTimeInSeconds        $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

#run SQLPlus
hSQLPlusOutput=`RunSQLCommand "$hCredentials" "$hSQL1 $hIdleTimeInSeconds" "$hSQLPlusExecutable" "$hTemporaryFile"`

if [ $? -eq 1 ]; then

	`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	exit 1

fi

hMailErrorCount=0
printf "SID\tSerial#\tProgram\tModule\tAction\tDBUsername\tHostname\tOSUser\tStatus\tLastCallET\n" > $hTemporaryFile

cat $hSQLPlusOutFile|while read LINE;
do

	`WriteLogFile $hScriptLogFile "Processing $hMailErrorCount=$LINE $hNewLine" "$hDateFormat"`

	if [ ! -z "$LINE" ]; then

		hSID=`GetColumnValue "$LINE" "1"`
		hSerialNo=`GetColumnValue "$LINE" "2"`
		hProgram=`GetColumnValue "$LINE" "3"`
		hModule=`GetColumnValue "$LINE" "4"`
		hAction=`GetColumnValue "$LINE" "5"`
		hUsername=`GetColumnValue "$LINE" "6"`
		hHostname=`GetColumnValue "$LINE" "7"`
		hOSUser=`GetColumnValue "$LINE" "8"`
		hStatus=`GetColumnValue "$LINE" "9"`
		hLastCallET=`GetColumnValue "$LINE" "10"`

		printf "$hSID\t$hSerialNo\t$hProgram\t$hModule\t$hAction\t$hUsername\t$hHostname\t$hOSUser\t$hStatus\t$hLastCallET\n" >> $hTemporaryFile

		hMailErrorCount=`expr $hMailErrorCount + 1`
		
	fi
	
done

if [ -f $hSQLPlusOutFile ]; then
	rm $hSQLPlusOutFile
fi

if [ "$hMailErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle [SessionCount=$hMailErrorCount]" "10"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`
	rm "$hTemporaryFile"
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
