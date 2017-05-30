#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	09-Sep-2008
#	Updation Date:	09-Sep-2008
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="WF InBound Mail Monitor [Mail Alert]"
hPageAlertTitle="WF InBound Mail Monitor [Page Alert]"

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
hTemporaryFile2=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "TemporaryFile2" "True")
hSQL1=""

hInboxFile=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "InboxFile" "True")
hProcessedFile=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ProcessedFile" "True")
hDiscardFile=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "DiscardFile" "True")

hMailLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailLimitInMinutes")
hPageLimit=$(GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "PageLimitInMinutes")

hConfigReadTime=$(GetElapsedTime)

# write Script Specific Details to logfile
$(WriteLogFile $hScriptLogFile "InboxFile:         $hInboxFile                $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "ProcessedFile:     $hProcessedFile            $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "DiscardFile:       $hDiscardFile              $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "MailLimit:         $hMailLimit mins           $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "PageLimit:         $hPageLimit mins           $hNewLine" "$hDateFormat")
$(WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat")

hMailErrorCount=0
hPageErrorCount=0

hInboxFileTimestamp=$(ls -E "$hInboxFile" | awk '{print $6$7}'|cut -d. -f1)
hProcessedFileTimestamp=$(ls -E "$hProcessedFile" | awk '{print $6$7}'|cut -d. -f1)
hDiscardFileTimestamp=$(ls -E "$hDiscardFile" | awk '{print $6$7}'|cut -d. -f1)

printf "Filename\tLast Update TimeStamp\tDifference in Minutes\tLimit\n" > $hTemporaryFile2

hSQL1="
SELECT ROUND((TO_DATE('$hInboxFileTimestamp','yyyy-mm-ddhh24:mi:ss') - TO_DATE('$hProcessedFileTimestamp','yyyy-mm-ddhh24:mi:ss')) * 1440)||CHR(9)||
ROUND((TO_DATE('$hInboxFileTimestamp','yyyy-mm-ddhh24:mi:ss') - TO_DATE('$hDiscardFileTimestamp','yyyy-mm-ddhh24:mi:ss')) * 1440) FROM dual
"

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

#cat $hSQLPlusOutFile|while read LINE;
echo "$hSQLPlusOutput"|while read LINE;
do

	if [ ! -z "$LINE" ]; then
	
		hLimit1=$(GetColumnValue "$LINE" "1")
		hLimit2=$(GetColumnValue "$LINE" "2")
		
		if [ "$hLimit1" -gt "$hLimit2" ]; then
			hLimit=$hLimit2
		else
			hLimit=$hLimit1
		fi

		if [ "$hLimit" -gt "$hPageLimit" ]; then
			hPageErrorCount=`expr $hPageErrorCount + 1`
		else
			if [ "$hLimit" -gt "$hMailLimit" ]; then
				hMailErrorCount=`expr $hMailErrorCount + 1`
			fi
		fi

		printf "$hInboxFile\t$hInboxFileTimestamp\t0\t MailLimit $hMailLimit min, PageLimit $hPageLimit min\n" >> $hTemporaryFile2
		printf "$hProcessedFile\t$hProcessedFileTimestamp\t$hLimit1\t MailLimit $hMailLimit min, PageLimit $hPageLimit min\n" >> $hTemporaryFile2
		printf "$hDiscardFile\t$hDiscardFileTimestamp\t$hLimit2\t MailLimit $hMailLimit min, PageLimit $hPageLimit min\n" >> $hTemporaryFile2

	fi

done

if [ "$hPageErrorCount" -gt 0 ]; then
	$(WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat")
	$(WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat")
	$(SendMultiLineEmail "$hTemporaryFile2" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle" "4") 
	$(WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat")
else
	$(WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat")

	if [ "$hMailErrorCount" -gt 0 ]; then
		$(WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat")
		$(WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat")
		$(SendMultiLineEmail "$hTemporaryFile2" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle" "4") 
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
