#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	09-Sep-2008
#	Updation Date:	09-Sep-2008
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="WF Queue Monitor [Mail Alert]"
hPageAlertTitle="WF Queue Monitor [Page Alert]"

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

hSQL1=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1")
hSQL2=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL2")

hWFQueueMailLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "WFQueueMailLimit")
hWFQueuePageLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "WFQueuePageLimit")

hConfigReadTime=$(GetElapsedTime)

# write Script Specific Details to logfile
$(WriteLogFile $hScriptLogFile "WFQueueMailLimit:  $hWFQueueMailLimit         $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "WFQueuePageLimit:  $hWFQueuePageLimit         $hNewLine" "$hDateFormat")
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
hComponentDown="False"

printf "Component Name\tComponent Status\tComponent Status Info\tLast Update TimeStamp\n" > $hTemporaryFile2

cat $hSQLPlusOutFile|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		hComponentName=$(GetColumnValue "$LINE" "1")
		hComponentStatus=$(GetColumnValue "$LINE" "2")
		hComponentStatusInfo=$(GetColumnValue "$LINE" "3")
		hComponentTimeStamp=$(GetColumnValue "$LINE" "4")

		if [ "$hComponentStatus" != "RUNNING" ]; then
			hComponentDown="True"
		fi

		printf "$hComponentName\t$hComponentStatus\t$hComponentStatusInfo\t$hComponentTimeStamp\n" >> $hTemporaryFile2

	fi
	
done

hSQLPlusOutput=$(RunSQLCommand "$hCredentials" "$hSQL2" "$hSQLPlusExecutable" "$hTemporaryFile")
cat $hSQLPlusOutFile|while read LINE;
do

	if [ ! -z "$LINE" ]; then
	
		hMailStatus=$(GetColumnValue "$LINE" "1")
		hStatus=$(GetColumnValue "$LINE" "2")
		hCount=$(GetColumnValue "$LINE" "3")
		hNID=$(GetColumnValue "$LINE" "4")

		if [ "$hComponentDown" = "True" ]; then
			printf "___TABLE___\t5\tWF Pending Notification Status\n" >> $hTemporaryFile2
			printf "Mail Status\tStatus\tPending Count\tLatest NID\tLimit\n" >> $hTemporaryFile2
		else
			printf "Mail Status\tStatus\tPending Count\tLatest NID\tLimit\n" > $hTemporaryFile2
		fi
		
		if [ "$hCount" -gt "$hWFQueuePageLimit" ]; then
			hPageErrorCount=`expr $hPageErrorCount + 1`
			printf "$hMailStatus\t$hStatus\t$hCount\t$hNID\t$hWFQueuePageLimit PageLimit\n" >> $hTemporaryFile2
		else
			if [ "$hCount" -gt "$hWFQueueMailLimit" ]; then
				hMailErrorCount=`expr $hMailErrorCount + 1`
				printf "$hMailStatus\t$hStatus\t$hCount\t$hNID\t$hWFQueueMailLimit MailLimit\n" >> $hTemporaryFile2
			fi
		fi

		# write history record
		hReturn=$(WriteHistoryRecord "$hConfigReadTime\t$hMailStatus\t$hStatus\t$hCount\t$hWFQueueMailLimit\t$hWFQueuePageLimit")

	fi
done

if [ "$hComponentDown" = "True" ]; then
	hPageErrorCount=`expr $hPageErrorCount + 1`
fi

if [ "$hPageErrorCount" -gt 0 ]; then
	$(WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat")
	$(SendMultiLineEmail "$hTemporaryFile2" "$hFromAlias" "$hPageAlias" "$hMailSubject [WF Queue CRITICAL COUNT=$hCount]" "$hPageAlertTitle" "4") 
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat")
else
	$(WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat")

	if [ "$hMailErrorCount" -gt 0 ]; then
		$(WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat")
		$(WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat")
		$(SendMultiLineEmail "$hTemporaryFile2" "$hFromAlias" "$hMailAlias" "$hMailSubject [WF Queue WARNING COUNT=$hCount]" "$hMailAlertTitle" "4") 
		$(WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat")
	else
		$(WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat")
	fi

fi

if [ -f "$hTemporaryFile" ]; then
	rm "$hTemporaryFile"
fi

if [ -f "$hTemporaryFile2" ]; then
	rm "$hTemporaryFile2"
fi

if [ -f $hSQLPlusOutFile ]; then
	rm $hSQLPlusOutFile
fi

$(WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat")

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
