#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	27-Jul-2010
#	Updation Date:	
###############################################################

# define Alert Title
hMailAlertTitle="Responsibility Monitor [Mail Alert]"
hPageAlertTitle="Responsibility Monitor [Page Alert]"

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
hExceptionFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ExceptionFile" "True"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "DataFile: $hDataFile                          $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ExceptionFile: $hExceptionFile                $hNewLine" "$hDateFormat"`

# Check if the exception file exists
if [ ! -f "$hExceptionFile" ]; then
	`WriteLogFile $hScriptLogFile "ExceptionFile: $hExceptionFile does not exist $hNewLine" "$hDateFormat"`
	
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hExceptionFile does not exist"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
	
fi


hResponsibilityList="''"
cat "$hExceptionFile"|while read LINE;
do

	hResponsibility=`GetColumnValue "$LINE" "1" ":"`
	hUserList=`GetColumnValue "$LINE" "2" ":"`
	
	hResponsibilityList=`echo $hResponsibilityList,"'"$hResponsibility"'"`

done

# generate a SQL File with all the responsibilities which needs to be queries
sed -e "s/\&1/$hResponsibilityList/" "$hSQL1" > "$hTemporaryFile.sql"
hSQL1="$hTemporaryFile.sql"

#run SQLPlus
hSQLPlusOutput=`RunSQLCommand "$hCredentials" "$hSQL1" "$hSQLPlusExecutable" "$hTemporaryFile"`

if [ $? -eq 1 ]; then

	`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	# remove the temporary sql created
	if [ -f "$hSQL1" ]; then
		rm "$hSQL1"
	fi
	
	if [ -f "$hSQLPlusOutFile" ]; then
		rm -f "$hSQLPlusOutFile"
	fi
	exit 1

fi

# remove the temporary sql created
if [ -f "$hSQL1" ]; then
	rm "$hSQL1"
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
		hResponsibilityName=`GetColumnValue "$LINE" "2"`
		hUsername=`GetColumnValue "$LINE" "3"`
		hStartDate=`GetColumnValue "$LINE" "4"`
		hEndDate=`GetColumnValue "$LINE" "5"`

		#if [ ! -f "$hDataFile" ]; then
		if [ $hMailErrorCount -eq 0 ]; then
			printf "___TABLE___\t6\t$hInstance\n" >> $hDataFile
			printf "Instance\tResponsibilityName\tUsername\tStart Date\tEnd Date\tStatus\n" >> $hDataFile
		fi
		
		#if [ $hMailErrorCount -eq 0 ]; then
		#	printf "Instance:<TD colspan=4>$hInstance</TD>\t___SKIPLINE___\n" >> $hDataFile
		#fi
		hOutput=`grep "$hResponsibilityName": "$hExceptionFile"|grep "$hUsername"`
		if [ ! -z "$hOutput" ]; then
			hStatus='Allowed'
		else

			hOutput=`grep "ALL:" "$hExceptionFile"|grep "$hUsername"`
			if [ ! -z "$hOutput" ]; then
				hStatus='Allowed'
			else
				hStatus='Not Allowed'
				printf "$hInstance\t$hResponsibilityName\t$hUsername\t$hStartDate\t$hEndDate\t$hStatus\n" >> $hDataFile
			fi
		fi
		hMailErrorCount=`expr $hMailErrorCount + 1`
		
	fi
	
done

if [ -f "$hDataFile" ]; then
	chmod -f 777 "$hDataFile"
	cp "$hDataFile" "$hTemporaryFile"
fi

rm "$hDataFile.lock"

if [ -f $hSQLPlusOutFile ]; then
	rm $hSQLPlusOutFile
fi

if [ "$hSendEMail" = "True" ]; then

	if [ "$hMailErrorCount" -gt 0 ]; then
		`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle [Count=$hMailErrorCount]" "6"` 
		`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
	else
		`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`
		if [ -f "$hTemporaryFile" ]; then
			rm "$hTemporaryFile"
		fi
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
