#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	18-Feb-2009
#	Updation Date:	19-Feb-2009
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="UNDO Tablespace Monitor [Mail Alert]"
hPageAlertTitle="UNDO Tablespace Monitor [Page Alert]"

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
hTemporaryFile2=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "TemporaryFile2" "True")

hSQL1=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1" "True")
hSQL2=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL2")

hMailCondition=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailCondition")
hPageCondition=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "PageCondition")
hListTopSessionCount=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ListTopSessionCount")

hConfigReadTime=$(GetElapsedTime)

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "MailCondition:     $hMailCondition            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "PageCondition:     $hPageCondition            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ListTopSession:    $hListTopSessionCount session(s) $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

#run SQLPlus
hSQLPlusOutput=$(RunSQLCommand "$hCredentials" "$hSQL1" "$hSQLPlusExecutable" "$hTemporaryFile")

if [ $? -eq 1 ]; then

	`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	exit 1

fi


# truncate temporary file

printf "Description\tValue\n" > $hTemporaryFile

hPageErrorCount=0
hMailErrorCount=0

cat "$hSQLPlusOutFile"|while read LINE;
do

	if [ ! -z "$LINE" ]; then


		hTSSizeInMB=$(GetColumnValue "$LINE" "1")
		hUndoPerSecInKB=$(GetColumnValue "$LINE" "2")
		hUndoForMaxQueryInMB=$(GetColumnValue "$LINE" "3")
		hMaxQueryLengthInSec=$(GetColumnValue "$LINE" "4")
		hUndoAdvisoryInMB=$(GetColumnValue "$LINE" "5")
		hMaxTRNSizeInMB=$(GetColumnValue "$LINE" "6")
		hTotalUsedSizeInMB=$(GetColumnValue "$LINE" "7")
		hTRNCount=$(GetColumnValue "$LINE" "8")
		hUndoRetentionInSec=$(GetColumnValue "$LINE" "9")
		hTunedUndoRetentionInSec=$(GetColumnValue "$LINE" "10")
		hMinTunedUndoRetentionInSec=$(GetColumnValue "$LINE" "11")
		
		echo "UNDO TableSpace Size [in MB]\t$hTSSizeInMB" >> $hTemporaryFile
		echo "UNDO/SEC [in KB]\t$hUndoPerSecInKB" >> $hTemporaryFile
		echo "UNDO Required based on MAX QUERY LENGTH [in MB]\t$hUndoForMaxQueryInMB" >> $hTemporaryFile
		echo "Max Query Length [in sec]\t$hMaxQueryLengthInSec" >> $hTemporaryFile
		echo "UNDO Required based on UNDO Advisory\t$hUndoAdvisoryInMB" >> $hTemporaryFile
		echo "Highest UNDO consuming transaction size [in MB]\t$hMaxTRNSizeInMB" >> $hTemporaryFile
		echo "Total UNDO Utilization [in MB]\t$hTotalUsedSizeInMB" >> $hTemporaryFile
		echo "Total Number of Active Transactions\t$hTRNCount" >> $hTemporaryFile
		echo "UNDO_RETENTION [v\$parameter]\t$hUndoRetentionInSec" >> $hTemporaryFile
		echo "V\$UNDOSTAT.tuned_undoretention [in sec]\t$hTunedUndoRetentionInSec" >> $hTemporaryFile
		echo "MIN of V\$UNDOSTAT.tuned_undoretention [in sec]\t$hMinTunedUndoRetentionInSec" >> $hTemporaryFile
		
		if [ "$hTunedUndoRetentionInSec" -le "$hPageCondition" ]; then
			hPageErrorCount=`expr $hPageErrorCount + 1`
		else
			if [ "$hTunedUndoRetentionInSec" -le "$hMailCondition" ]; then
				hMailErrorCount=`expr $hMailErrorCount + 1`
			fi
		fi
		
		# write history record
		hReturn=$(WriteHistoryRecord "$hConfigReadTime\t$hTSSizeInMB\t$hUndoPerSecInKB\t$hUndoForMaxQueryInMB\t$hMaxQueryLengthInSec\t$hUndoAdvisoryInMB\t$hMaxTRNSizeInMB\t$hTotalUsedSizeInMB\t$hTRNCount\t$hUndoRetentionInSec\t$hTunedUndoRetentionInSec\t$hMinTunedUndoRetentionInSec")

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
			printf "___TABLE___\t10\tTop UNDO Consuming Sessions\n" >> $hTemporaryFile
			printf "SID\tSerialNo\tProgram\tModule\tAction\tDB Username\tOS Username\t$UNDO Used [MB]\tSQL\n" >> $hTemporaryFile
		fi
		
		cat $hSQLPlusOutFile|while read LINE;
		do

			if [ ! -z "$LINE" ]; then

				hSID=`GetColumnValue "$LINE" "1"`
				hSerialNo=`GetColumnValue "$LINE" "2"`
				hProgram=`GetColumnValue "$LINE" "3"`
				hModule=`GetColumnValue "$LINE" "4"`
				hAction=`GetColumnValue "$LINE" "5"`
				hUsername=`GetColumnValue "$LINE" "6"`
				hOSUser=`GetColumnValue "$LINE" "7"`
				hSizeMB=`GetColumnValue "$LINE" "8"`
				hSQLText=`GetColumnValue "$LINE" "9"`

				printf "$hSID\t$hSerialNo\t$hProgram\t$hModule\t$hAction\t$hUsername\t$hOSUser\t$hSizeMB\t$hSQLText\n" >> $hTemporaryFile

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
	`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle" "2"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`

	if [ "$hPageErrorCount" -gt 0 ]; then
		`WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle" "2"` 
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	else
		`WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat"`
	fi

fi

if [ -f $hTemporaryFile ]; then
	rm $hTemporaryFile
fi

if [ -f $hTemporaryFile2 ]; then
	rm $hTemporaryFile2
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
