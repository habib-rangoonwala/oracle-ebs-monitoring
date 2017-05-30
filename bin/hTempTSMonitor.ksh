#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	18-Feb-2009
#	Updation Date:	19-Feb-2009
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="Temp TS Monitor [Mail Alert]"
hPageAlertTitle="Temp TS Monitor [Page Alert]"

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
hTemporaryFile2=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "TemporaryFile2" "True"`
hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1"`
hSQL2=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL2"`

hMailCondition=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailCondition"`
hPageCondition=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "PageCondition"`
hListTopSessionCount=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ListTopSessionCount"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "MailCondition:     $hMailCondition            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "PageCondition:     $hPageCondition            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ListTopSession:    $hListTopSessionCount session(s) $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`
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
echo "Tablespace Name\tTotal Size[GB]\tUsed Size[GB]\tFree Size[GB]\tMax Size[GB] Ever Used\tMax Size[GB] Used by Sorts\tUsed Percentage" > $hTemporaryFile

hPageErrorCount=0
hMailErrorCount=0

cat $hSQLPlusOutFile|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		hTablespaceName=`GetColumnValue "$LINE" "1"`
		hTotalSize=`GetColumnValue "$LINE" "2"`
		hUsedSize=`GetColumnValue "$LINE" "3"`
		hFreeSize=`GetColumnValue "$LINE" "4"`
		hMaxSize=`GetColumnValue "$LINE" "5"`
		hMaxUsedSize=`GetColumnValue "$LINE" "6"`
		hUsedPercentage=`GetColumnValue "$LINE" "7"`

		
		echo "$hTablespaceName\t$hTotalSize\t$hUsedSize\t$hFreeSize\t$hMaxSize\t$hMaxUsedSize\t$hUsedPercentage" >> $hTemporaryFile

		if [ "$hUsedPercentage" -ge "$hPageCondition" ]; then
			hPageErrorCount=`expr $hPageErrorCount + 1`
		else
			if [ "$hUsedPercentage" -ge "$hMailCondition" ]; then
				hMailErrorCount=`expr $hMailErrorCount + 1`
			fi
		fi
		
		# write history record
		hTotalTime=`GetElapsedTime`
		hReturn=`WriteHistoryRecord "$hTablespaceName\t$hTotalSize\t$hUsedSize\t$hFreeSize\t$hMaxSize\t$hMaxUsedSize\t$hUsedPercentage\t$hTotalTime"`

	fi

done

# check if the top sessions/queries to be listed
if [ "$hListTopSessionCount" -gt 0 ]; then

	if [ "$hMailErrorCount" -gt 0 -o "$hPageErrorCount" -gt 0 ]; then

		hSQLPlusOutput=`RunSQLCommand "$hCredentials" "$hSQL2 $hListTopSessionCount" "$hSQLPlusExecutable" "$hTemporaryFile2"`

		if [ $? -eq 1 ]; then

			`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
			`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

			`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
			`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput"`
			`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

			exit 1

		fi
		
		if [ ! -z "$hSQLPlusOutput" ]; then
			printf "___TABLE___\t10\tTop SORT Consuming Sessions\n" >> $hTemporaryFile
			printf "Tablespace\tSID\tSerialNo\tProgram\tModule\tAction\tDB Username\tOS Username\t$Temp Used [MB]\tSQL\n" >> $hTemporaryFile
		fi
		
		cat $hSQLPlusOutFile|while read LINE;
		do

			if [ ! -z "$LINE" ]; then

				hTablespace=`GetColumnValue "$LINE" "1"`
				hSID=`GetColumnValue "$LINE" "2"`
				hSerialNo=`GetColumnValue "$LINE" "3"`
				hProgram=`GetColumnValue "$LINE" "4"`
				hModule=`GetColumnValue "$LINE" "5"`
				hAction=`GetColumnValue "$LINE" "6"`
				hUsername=`GetColumnValue "$LINE" "7"`
				hOSUser=`GetColumnValue "$LINE" "8"`
				hSizeMB=`GetColumnValue "$LINE" "9"`
				hSQLText=`GetColumnValue "$LINE" "10"`

				printf "$hTablespace\t$hSID\t$hSerialNo\t$hProgram\t$hModule\t$hAction\t$hUsername\t$hOSUser\t$hSizeMB\t$hSQLText\n" >> $hTemporaryFile

			fi

		done

		
	fi

fi

if [ -f $hSQLPlusOutFile ]; then
	rm $hSQLPlusOutFile
fi

if [ "$hMailErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle" "7"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`

	if [ "$hPageErrorCount" -gt 0 ]; then
		`WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle" "7"` 
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	else
		`WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat"`
		rm "$hTemporaryFile"
	fi

fi

if [ -f $hTemporaryFile ]; then
	rm $hTemporaryFile
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
