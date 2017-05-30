#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	09-Sep-2008
#	Updation Date:	09-Sep-2008
#	Updation Date:	19-Feb-2009
###############################################################


# define Alert Title
hMailAlertTitle="CM Queue Monitor [Mail Alert]"
hPageAlertTitle="CM Queue Monitor [Page Alert]"

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
hSQL2=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL2" "True")
hQueueMailLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "QueueMailLimit")
hQueuePageLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "QueuePageLimit")

hConfigReadTime=$(GetElapsedTime)

# write Script Specific Details to logfile
$(WriteLogFile $hScriptLogFile "QueueMailLimit:    $hQueueMailLimit           $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "QueuePageLimit:    $hQueuePageLimit           $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat")

#run SQLPlus [find out CM Status]

hSQLPlusOutput=$(RunSQLCommand "$hCredentials" "$hSQL2" "$hSQLPlusExecutable" "$hTemporaryFile")

if [ $? -eq 1 ]; then

	$(WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat")

	$(WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat")
	$(SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput")
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat")

	exit 1

fi

hCMStatus=`echo "$hSQLPlusOutput" | grep DOWN`

if [ ! -z "$hCMStatus" ]; then

	$(WriteLogFile $hScriptLogFile "Page Alert: CM is DOWN $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "Output: $hSQLPlusOutput $hNewLine" "$hDateFormat")
	
	$(WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat")
	$(SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject: CM-DOWN" "$hPageAlertTitle" "CM is DOWN [$hSQLPlusOutput]")
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat")

	exit 1

fi

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

hQueueMailLimit=$(ReplaceString "$hQueueMailLimit" ";" "\n")
hQueuePageLimit=$(ReplaceString "$hQueuePageLimit" ";" "\n")

# find out the DEFAULT mail limit
hDefaultString=$(echo "$hQueueMailLimit" | grep "DEFAULT")
hDefaultMailLimit=$(echo "$hDefaultString"|cut -d: -f2)

# find out the DEFAULT page limit
hDefaultString=$(echo "$hQueuePageLimit" | grep "DEFAULT")
hDefaultPageLimit=$(echo "$hDefaultString"|cut -d: -f2)

# create two files [one for page alert and other for mail alert]
hMailFile=$hTemporaryFile.mail
hPageFile=$hTemporaryFile.page

hMailErrorCount=0
hPageErrorCount=0

printf "Queue Name\tQueue Description\tMax Processes\tRunning Processes\tRunning Requests\tPending Requests\tMail Condition\tStatus\n" > $hMailFile
printf "Queue Name\tQueue Description\tMax Processes\tRunning Processes\tRunning Requests\tPending Requests\tPage Condition\tStatus\n" > $hPageFile

cat $hSQLPlusOutFile|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		hQueueName=$(GetColumnValue "$LINE" "1")
		hQueueDescription=$(GetColumnValue "$LINE" "2")
		hMaxProcesses=$(GetColumnValue "$LINE" "3")
		hRunningProcesses=$(GetColumnValue "$LINE" "4")
		hPending=$(GetColumnValue "$LINE" "5")
		hRunningRequests=$(GetColumnValue "$LINE" "6")

		hMailString=$(echo "$hQueueMailLimit" | grep "$hQueueName")
		hMailQueueNameToCheck=$(echo "$hMailString"|cut -d: -f1)
		hMailLimit=$(echo "$hMailString"|cut -d: -f2)

		hPageString=$(echo "$hQueuePageLimit" | grep "$hQueueName")
		hPageQueueNameToCheck=$(echo "$hPageString"|cut -d: -f1)
		hPageLimit=$(echo "$hPageString"|cut -d: -f2)
		
		hStatus="OK"

		# check if PENDING request satiesfies MAIL CONDITION or DEFAULT MAILCONDITION
		if [ "$hQueueName" = "$hMailQueueNameToCheck" ]; then

			if [ "$hPending" -ge "$hMailLimit" ]; then

				hMailErrorCount=$(expr $hMailErrorCount + 1)
				if [ "$hPending" -ge "$hPageLimit" ]; then
					hStatus="CRITICAL"
				else
					hStatus="WARNING"
				fi
			fi

		else

			hMailLimit="$hDefaultMailLimit*"

			if [ "$hPending" -ge "$hDefaultMailLimit" ]; then

				hMailErrorCount=$(expr $hMailErrorCount + 1)
				if [ "$hPending" -ge "$hPageLimit" ]; then
					hStatus="CRITICAL"
				else
					hStatus="WARNING"
				fi

			fi

		fi

		# no matter if mail alert is satiesfied, write to mailfile
		printf "$hQueueName\t$hQueueDescription\t$hMaxProcesses\t$hRunningProcesses\t$hRunningRequests\t$hPending\t$hMailLimit\t$hStatus\n" >> $hMailFile
		
		# check if PENDING request satisfies PAGE CONDITION or DEFAULT PAGECONDITION
		if [ "$hQueueName" = "$hPageQueueNameToCheck" ]; then
		
			if [ "$hPending" -ge "$hPageLimit" ]; then

				hPageErrorCount=$(expr $hPageErrorCount + 1)
				hStatus="CRITICAL"
				
			fi
		
		else

			hPageLimit="$hDefaultPageLimit*"

			if [ "$hPending" -ge "$hDefaultPageLimit" ]; then

				hPageErrorCount=$(expr $hPageErrorCount + 1)
				hStatus="CRITICAL*"

			fi

		fi

		# if PAGE ALERT is satisfied then write to PageFile
		if [ "$hStatus" = "CRITICAL" ] || [ "$hStatus" = "CRITICAL*" ]; then
			printf "$hQueueName\t$hQueueDescription\t$hMaxProcesses\t$hRunningProcesses\t$hRunningRequests\t$hPending\t$hPageLimit\t$hStatus\n" >> $hPageFile
		fi
		
		# write history record
		hReturn=$(WriteHistoryRecord "$hConfigReadTime\t$hQueueName\t$hMaxProcesses\t$hRunningProcesses\t$hRunningRequests\t$hPending\t$hMailLimit\t$hPageLimit\t$hStatus")
		
	fi
	
done

if [ "$hMailErrorCount" -gt 0 ]; then
	$(WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat")
	$(SendMultiLineEmail "$hMailFile" "$hFromAlias" "$hMailAlias" "$hMailSubject [$hMailErrorCount Queue(s) reported]" "$hMailAlertTitle" "9") 
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat")
else
	$(WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat")
	rm "$hMailFile"
fi

if [ "$hPageErrorCount" -gt 0 ]; then
	$(WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat")
	$(SendMultiLineEmail "$hPageFile" "$hFromAlias" "$hPageAlias" "$hMailSubject [$hPageErrorCount Queue(s) reported]" "$hPageAlertTitle" "9") 
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat")
else
	$(WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat")
	rm "$hPageFile"
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

