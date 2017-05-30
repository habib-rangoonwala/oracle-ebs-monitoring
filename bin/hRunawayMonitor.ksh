#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	01-Sep-2008
#	Updation Date:	01-Sep-2008
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="Runaway Monitor [Mail Alert]"
hPageAlertTitle="Runaway Monitor [Page Alert]"

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
hTemporaryFile1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "TemporaryFile1" "True"`
hTemporaryFile2=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "TemporaryFile2" "True"`

hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1"`
hSQL2=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL2"`

hCPULimit=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CPULimit"`
hCommand1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "Command1"`
hDBSessionIdleLimit=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "DBSessionIdleLimit"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "TemporaryFile1:    $hTemporaryFile1           $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "TemporaryFile2:    $hTemporaryFile2           $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "CPULimit:          $hCPULimit                 $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "DBSessionIdleLimit:$hDBSessionIdleLimit sec   $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Command1:          $hCommand1                 $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

# run PS command to get the output

echo "$hCommand1" > $hTemporaryFile2
chmod 755 $hTemporaryFile2
hOutput=`sh $hTemporaryFile2`
hMailErrorCount=0
hPID=0

hHeaderPrinted=0
hDBSessionFound=0

# truncate temporary file

echo "OS-PID\tCPU\tOSUser\tCommand\tSID\tSerial#\tProgram\tModule\tAction\tUsername\tHostname\tStatus\tLastCallET" > $hTemporaryFile2
hCPULimit=`echo "$hCPULimit * 100"|bc`

echo "$hOutput"|while read LINE;
do

	if [ -z "$LINE" ]; then
		break;
	fi

	hHeaderPrinted=0
	hDBSessionFound=0
	hLastCallET=0
	
	hCPU=`echo $LINE|awk '{print $2}`
	hCPU=`echo "$hCPU * 100"|bc`
	
	if [ "$hCPU" -ge "$hCPULimit" ]; then
	
		`WriteLogFile $hScriptLogFile "Verifying Process $LINE $hNewLine" "$hDateFormat"`

		hPID=`GetColumnValue "$LINE" "1"`
		hCPU=`GetColumnValue "$LINE" "2"`
		hUser=`GetColumnValue "$LINE" "3"`
		hComm=`GetColumnValue "$LINE" "4"`

		#run SQLPlus [without V$process]

		hSQLPlusOutput=`RunSQLCommand "$hCredentials" "$hSQL1 '$hPID'" "$hSQLPlusExecutable" "$hTemporaryFile1"`

		if [ $? -eq 1 ]; then

			`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
			`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

			`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
			`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput"`
			`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

			exit 1

		fi

		#echo "$hSQLPlusOutput"|while read LINE2;
		cat "$hSQLPlusOutFile"|while read LINE2;
		do
		
			if [ ! -z "$LINE2" ]; then

				hDBSessionFound=1

				hSID=`GetColumnValue "$LINE2" "1"`
				hSerialNo=`GetColumnValue "$LINE2" "2"`
				hProgram=`GetColumnValue "$LINE2" "3"`
				hModule=`GetColumnValue "$LINE2" "4"`
				hAction=`GetColumnValue "$LINE2" "5"`
				hUsername=`GetColumnValue "$LINE2" "6"`
				hHostname=`GetColumnValue "$LINE2" "7"`
				hStatus=`GetColumnValue "$LINE2" "8"`
				hLastCallET=`GetColumnValue "$LINE2" "9"`


				if [ "$hLastCallET" -ge "$hDBSessionIdleLimit" ]; then
				
					if [ $hHeaderPrinted -eq 0 ]; then
						echo "$hPID\t$hCPU\t$hUser\t$hComm\t-\t-\t-\t-\t-\t-\t-\t-\t-" >> $hTemporaryFile2
						hHeaderPrinted=1
					fi

					echo "-\t-\t-\t-\t$hSID\t$hSerialNo\t$hProgram\t$hModule\t$hAction\t$hUsername\t$hHostname\t$hStatus\t$hLastCallET" >> $hTemporaryFile2

				else

					`WriteLogFile $hScriptLogFile "Skipping SID=$hSID CurrentLastCallET=$hLastCallET $hNewLine" "$hDateFormat"`

				fi

			fi

		done

		#run SQLPlus 2 [with v$process]

		hSQLPlusOutput=`RunSQLCommand "$hCredentials" "$hSQL2 '$hPID'" "$hSQLPlusExecutable" "$hTemporaryFile1"`

		if [ $? -eq 1 ]; then

			`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
			`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

			`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
			`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "$hSQLPlusOutput"`
			`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

			exit 1

		fi

		#echo "$hSQLPlusOutput"|while read LINE2;
		cat "$hSQLPlusOutFile"|while read LINE2;
		do

			if [ ! -z "$LINE2" ]; then

				hDBSessionFound=1

				hSID=`GetColumnValue "$LINE2" "1"`
				hSerialNo=`GetColumnValue "$LINE2" "2"`
				hProgram=`GetColumnValue "$LINE2" "3"`
				hModule=`GetColumnValue "$LINE2" "4"`
				hAction=`GetColumnValue "$LINE2" "5"`
				hUsername=`GetColumnValue "$LINE2" "6"`
				hHostname=`GetColumnValue "$LINE2" "7"`
				hStatus=`GetColumnValue "$LINE2" "8"`
				hLastCallET=`GetColumnValue "$LINE2" "9"`

				if [ "$hLastCallET" -ge "$hDBSessionIdleLimit" ]; then

					if [ $hHeaderPrinted -eq 0 ]; then
						echo "$hPID\t$hCPU\t$hUser\t$hComm\t-\t-\t-\t-\t-\t-\t-\t-\t-" >> $hTemporaryFile2
						hHeaderPrinted=1
					fi

					echo "-\t-\t-\t-\t$hSID\t$hSerialNo\t$hProgram\t$hModule\t$hAction\t$hUsername\t$hHostname\t$hStatus\t$hLastCallET" >> $hTemporaryFile2

				else

					`WriteLogFile $hScriptLogFile "Skipping SID=$hSID CurrentLastCallET=$hLastCallET $hNewLine" "$hDateFormat"`

				fi

			fi

		done
		
		if [ $hDBSessionFound -eq 0 -a $hHeaderPrinted -eq 0 ]; then
			echo "$hPID\t$hCPU\t$hUser\t$hComm\t-\t-\t-\t-\t-\t-\t-\t-\t-" >> $hTemporaryFile2
			hHeaderPrinted=1
		fi
		
		if [ $hHeaderPrinted -eq 1 ]; then
			hMailErrorCount=`expr $hMailErrorCount + 1`
		fi
	else
	
		`WriteLogFile $hScriptLogFile "Skipped Process $LINE $hNewLine" "$hDateFormat"`

	fi
	
done

if [ -f "$hSQLPlusOutFile" ]; then
	rm "$hSQLPlusOutFile"
fi

if [ "$hMailErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFile2" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle [ProcessCount=$hMailErrorCount]" "13"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`
	rm "$hTemporaryFile2"
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile1
mv $hTemporaryFile1 $hScriptLogFile
exit 0
