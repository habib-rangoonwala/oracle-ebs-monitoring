#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	27-May-2007
#	Updation Date:	02-Aug-2007
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="Tablespace Monitor [Mail Alert]"
hPageAlertTitle="Tablespace Monitor [Page Alert]"

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
hTemporaryFileMail=$hTemporaryFile.mail
hTemporaryFilePage=$hTemporaryFile.page

hMailCondition=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailCondition"`
hPageCondition=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "PageCondition"`
hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "MailCondition:     $hMailCondition            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "PageCondition:     $hPageCondition            $hNewLine" "$hDateFormat"`
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

# find out mail/page percentage
hMailPCT=`echo "$hMailCondition"|cut -d, -f1`
hMailMB=`echo "$hMailCondition"|cut -d, -f2`

hPagePCT=`echo "$hPageCondition"|cut -d, -f1`
hPageMB=`echo "$hPageCondition"|cut -d, -f2`

# truncate temporary files

echo "Tablespace Name\tTotal Size [MB]\tUsed Space [MB]\tFree Space [MB]\tFree [%]" > $hTemporaryFileMail
echo "Tablespace Name\tTotal Size [MB]\tUsed Space [MB]\tFree Space [MB]\tFree [%]" > $hTemporaryFilePage

hPageErrorCount=0
hMailErrorCount=0

#echo "$hSQLPlusOutput"|while read LINE;
cat "$hSQLPlusOutFile"|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		hTSName=`GetColumnValue "$LINE" "1"`
		hTotalMB=`GetColumnValue "$LINE" "2"`
		hUsedMB=`GetColumnValue "$LINE" "3"`
		hFreeMB=`GetColumnValue "$LINE" "4"`
		hFreePCT=`GetColumnValue "$LINE" "5"`

		hFreePCT=`expr 100 - $hFreePCT`
		
		# check for mail condition
		if [ "$hFreePCT" -lt "$hMailPCT" -a "$hFreeMB" -lt "$hMailMB" ]; then
			echo "$hTSName\t$hTotalMB\t$hUsedMB\t$hFreeMB\t$hFreePCT" >> $hTemporaryFileMail
			hMailErrorCount=`expr $hMailErrorCount + 1`
		fi

		# check for page condition
		if [ "$hFreePCT" -lt "$hPagePCT" -a "$hFreeMB" -lt "$hPageMB" ]; then
			echo "$hTSName\t$hTotalMB\t$hUsedMB\t$hFreeMB\t$hFreePCT" >> $hTemporaryFilePage
			hPageErrorCount=`expr $hPageErrorCount + 1`
		fi
		
	fi

done

if [ "$hMailErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFileMail" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle" "5"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`
	rm "$hTemporaryFileMail"
fi

if [ "$hPageErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Page Alert Count $hPageErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFilePage" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle" "5"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Page Alert $hNewLine" "$hDateFormat"`
	rm "$hTemporaryFilePage"
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

if [ -f "$hSQLPlusOutFile" ]; then
	rm $hSQLPlusOutFile
fi

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
