#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	09-Sep-2008
#	Updation Date:	09-Sep-2008
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="SFM Queue Monitor [Mail Alert]"
hPageAlertTitle="SFM Queue Monitor [Page Alert]"

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
hSQL1=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1")

hSFMQueueMailLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SFMQueueMailLimit")
hSFMQueuePageLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SFMQueuePageLimit")

hConfigReadTime=$(GetElapsedTime)

# write Script Specific Details to logfile
$(WriteLogFile $hScriptLogFile "SFMQueueMailLimit: $hSFMQueueMailLimit        $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "SFMQueuePageLimit: $hSFMQueuePageLimit        $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat")

#run SQLPlus

hSQLPlusOutput=$(RunSQLCommand "$hCredentials" "$hSQL1" "$hSQLPlusExecutable" "$hTemporaryFile")

if [ $? -eq 1 ]; then

	$(WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat")

	$(WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat")
	$(SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput")
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat")

	exit 1

fi

hMailErrorCount=0
hPageErrorCount=0

printf "Status\tCount\tLast Message TimeStamp\tLimit\n" > $hTemporaryFile

cat $hSQLPlusOutFile|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		hMessageStatus=$(GetColumnValue "$LINE" "1")
		hMessageCount=$(GetColumnValue "$LINE" "2")
		hLastMessageTimeStamp=$(GetColumnValue "$LINE" "3")
		hLimit=""

		if [ "$hMessageStatus" = "READY" ]; then
			if [ "$hMessageCount" -gt "$hSFMQueuePageLimit" ]; then
				
				hPageErrorCount=$hMessageCount
				hLimit="$hSFMQueuePageLimit page limit"

			else
				if [ "$hMessageCount" -gt "$hSFMQueueMailLimit" ]; then
					
					hMailErrorCount=$hMessageCount
					hLimit="$hSFMQueueMailLimit mail limit"
					
				fi
			fi
		fi

		printf "$hMessageStatus\t$hMessageCount\t$hLastMessageTimeStamp\t$hLimit\n" >> $hTemporaryFile

		# write history record
		hReturn=$(WriteHistoryRecord "$hConfigReadTime\t$hMessageStatus\t$hMessageCount\t$hSFMQueueMailLimit\t$hSFMQueuePageLimit")

	fi
	
done

if [ "$hPageErrorCount" -gt 0 ]; then
	$(WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat")
	$(SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject [SFM Queue Critical COUNT=$hPageErrorCount]" "$hPageAlertTitle" "4") 
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat")
else
	$(WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat")

	if [ "$hMailErrorCount" -gt 0 ]; then
		$(WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat")
		$(WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat")
		$(SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject [SFM Queue Warning COUNT=$hMailErrorCount]" "$hMailAlertTitle" "4") 
		$(WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat")
	else
		$(WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat")
	fi

fi

if [ -f "$hTemporaryFile" ]; then
	rm "$hTemporaryFile"
fi

if [ -f $hSQLPlusOutFile ]; then
	rm $hSQLPlusOutFile
fi

$(WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat")

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0

