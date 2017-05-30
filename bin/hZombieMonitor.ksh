#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	08-Sep-2008
#	Updation Date:	08-Sep-2008
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="Zombie Monitor [Mail Alert]"
hPageAlertTitle="Zombie Monitor [Page Alert]"

# source the main environment file
hDirName=`dirname $0`
. $hDirName/hInitialize.ksh "$0"
if [ $? -eq 1 ]; then
	exit 1
fi

# Read Script Specific Configuration Parameter
hCommand1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "Command1"`
hCommand2=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "Command2"`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "Command1:          $hCommand1                 $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Command2:          $hCommand2                 $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

# run PS command to get the output
echo "$hCommand1" > $hTemporaryFile
chmod 755 $hTemporaryFile
hOutput=`sh $hTemporaryFile`
hCount=`echo "$hOutput"|wc -l`
hMailErrorCount=0
hPID=0

# truncate temporary file
echo "PPID\tPID\tCommand\tOwner\tCPU\tMemory\tTime\tParent Process" > $hTemporaryFile

`WriteLogFile $hScriptLogFile "Processing $hCount entries $hNewLine" "$hDateFormat"`

echo "$hOutput"|while read LINE;
do

	if [ -z "$LINE" ]; then
		break;
	fi

	hPPID=`GetColumnValue "$LINE" "1"`
	hPID=`GetColumnValue "$LINE" "2"`
	hStatus=`GetColumnValue "$LINE" "3"`
	hComm=`GetColumnValue "$LINE" "4"`
	hOwner=`GetColumnValue "$LINE" "5"`
	hCPU=`GetColumnValue "$LINE" "6"`
	hMemory=`GetColumnValue "$LINE" "7"`
	hTime=`GetColumnValue "$LINE" "8"`
	
	if [ ! -z "$hPPID" ]; then
		hPS=`ps -p $hPPID -o "comm args"|tail -1`
	else
		hPS="."
	fi
	
	if [ "$hStatus" = "Z" ]; then

		`WriteLogFile $hScriptLogFile "Sleeping for 10 Seconds and rechecking PID=$hPID $hNewLine" "$hDateFormat"`

		# wait for 10 sec to get it cleared automatically
		sleep 10
		
		echo "$hCommand2 $hPID" > $hTemporaryFile.2
		chmod 755 $hTemporaryFile.2
		hOutput2=`sh $hTemporaryFile.2`
		rm $hTemporaryFile.2
		LINE2=`echo "$hOutput2"|grep $hPID`
		hStatus=`echo $LINE2 |cut -d " " -f3`
		
		if [ "$hStatus" = "Z" ]; then
		
			`WriteLogFile $hScriptLogFile "PID=$hPID OWNER=$hOwner - $hComm -  is in ZOMBIE status after recheck $hNewLine" "$hDateFormat"`
		
			echo "$hPPID\t$hPID\t$hComm\t$hOwner\t$hCPU\t$hMemory\t$hTime\t$hPS" >> $hTemporaryFile
			hMailErrorCount=`expr $hMailErrorCount + 1`
		fi
		
	fi

done

if [ "$hMailErrorCount" -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Mail Alert Count $hMailErrorCount $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle [ProcessCount=$hMailErrorCount]" "8"` 
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "No Mail Alert $hNewLine" "$hDateFormat"`
fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

if [ -f "$hTemporaryFile" ]; then
	rm "$hTemporaryFile"
fi

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
