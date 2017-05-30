#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	27-May-2007
#	Updation Date:	02-Aug-2007
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="OS Monitor [Mail Alert]"
hPageAlertTitle="OS Monitor [Page Alert]"

# source the main environment file
hDirName=`dirname $0`
. $hDirName/hInitialize.ksh "$0"
if [ $? -eq 1 ]; then
	exit 1
fi

# Read Script Specific Configuration Parameter
hCPUMailLimit=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CPUMailLimit" "True"`
hCPUPageLimit=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CPUPageLimit" "True"`

hLoadMailLimit=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "LoadMailLimit" "True"`
hLoadPageLimit=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "LoadPageLimit" "True"`

hShowTopProcesses=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ShowTopProcesses"`

hConfigReadTime=`GetElapsedTime`

# write Script Specific Details to logfile

`WriteLogFile $hScriptLogFile "CPUMailLimit:      $hCPUMailLimit             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "CPUPageLimit:      $hCPUPageLimit             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "LoadMailLimit:     $hLoadMailLimit            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "LoadPageLimit:     $hLoadPageLimit            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ShowTopProcesses:  $hShowTopProcesses         $hNewLine" "$hDateFormat"`

`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

if [ `uname` = 'SunOS' ]; then
	hOutput=`iostat -c 1 20 |awk '{print $4}'|grep -v id`
elif [ `uname` = 'Linux' ]; then
	hOutput=`iostat -c 1 20 |grep -v "avg-cpu:"|awk '{print $6}'|awk -F. '{print $1}'|grep -v id`
fi

hCPUTotal=0
hCount=0

for hLoad in $hOutput
do
	if [ ! -z "$hLoad" ]; then
		hCPUTotal=`expr $hCPUTotal + $hLoad`
		hCount=`expr $hCount + 1`
	fi
done

hCPUBusy=`expr 100 - $hCPUTotal / $hCount `

if [ "$hShowTopProcesses" -gt 0 ]; then

	hShowTopProcesses1=`expr $hShowTopProcesses + 1`
	if [ `uname` = 'SunOS' ]; then
		hOutput=`top -n $hShowTopProcesses|tail -$hShowTopProcesses1`
	elif [ `uname` = 'Linux' ]; then
		hOutput=`top -b -n 1|tail -$hShowTopProcesses1`
	fi
	
	echo "PID\tUsername\tTime\tCPU\tCommand" > "$hTemporaryFile"
	
	echo "$hOutput"|while read LINE;
	do
	
		if [ ! -z "$LINE" ]; then
	
			if [ `uname` = 'SunOS' ]; then
				hPID=`echo $LINE|cut -d " " -f1`
				hUsername=`echo $LINE|cut -d " " -f2`
				hTime=`echo $LINE|cut -d " " -f9`
				hCPU=`echo $LINE|cut -d " " -f10`
				hCommand=`echo $LINE|cut -d " " -f11`
			elif [ `uname` = 'Linux' ]; then
				hPID=`echo $LINE|cut -d " " -f1`
				hUsername=`echo $LINE|cut -d " " -f2`
				hTime=`echo $LINE|cut -d " " -f11`
				hCPU=`echo $LINE|cut -d " " -f9`
				hCommand=`echo $LINE|cut -d " " -f12`
			fi

			#hPID=`GetColumnValue "$LINE" "1"`
			#hUsername=`GetColumnValue "$LINE" "2"`
			#hTime=`GetColumnValue "$LINE" "9"`
			#hCPU=`GetColumnValue "$LINE" "10"`
			#hCommand=`GetColumnValue "$LINE" "11"`

			
			echo "$hPID\t$hUsername\t$hTime\t$hCPU\t$hCommand" >> "$hTemporaryFile"

		fi
	
	done

	# copy it to .2, because SendMultilineEmail deletes the temp files
	# this .2 is used in LoadAvg alert
	cp "$hTemporaryFile" "$hTemporaryFile.2"

fi


if [ "$hCPUBusy" -ge "$hCPUPageLimit" ]; then

	hMessage="CPU is [$hCPUBusy%] Busy. Crossed Page Limit [$hCPUPageLimit%]"

	`WriteLogFile $hScriptLogFile "$hMessage" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	if [ "$hShowTopProcesses" -gt 0 ]; then
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject:CPU=$hCPUBusy%" "$hPageAlertTitle <br> [$hMessage]" "5"` 
	else
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject:CPU=$hCPUBusy%" "$hPageAlertTitle" "$hMessage"`
	fi
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

elif [ "$hCPUBusy" -ge "$hCPUMailLimit" ]; then

	hMessage="CPU is [$hCPUBusy%] Busy. Crossed Mail Limit [$hCPUMailLimit%]"

	`WriteLogFile $hScriptLogFile "$hMessage" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	if [ "$hShowTopProcesses" -gt 0 ]; then
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject:CPU=$hCPUBusy%" "$hMailAlertTitle <br> [$hMessage]" "5"` 
	else
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject:CPU=$hCPUBusy%" "$hMailAlertTitle" "$hMessage"`
	fi
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`

fi

# uptime | sed -e 's/.*load average: \(.*\...\), \(.*\...\), \(.*\...\)/\1/' -e 's/ //g'
if [ `uname` = 'SunOS' ]; then
	hLoadAvg=`uptime|awk -F: '{print $4}'|awk -F, '{print $1}'`
elif [ `uname` = 'Linux' ]; then
	hLoadAvg=`uptime|awk -F: '{print $5}'|awk -F, '{print $1}'`
fi

if [ "$hLoadAvg" -ge "$hLoadPageLimit" ]; then

	hMessage="Load Average [$hLoadAvg] has crossed allowed Load Average Page Limit of [$hLoadPageLimit]"

	`WriteLogFile $hScriptLogFile "$hMessage" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	if [ "$hShowTopProcesses" -gt 0 ]; then
		`SendMultiLineEmail "$hTemporaryFile.2" "$hFromAlias" "$hPageAlias" "$hMailSubject:LoadAvg=$hLoadAvg" "$hPageAlertTitle <br> [$hMessage]" "5"` 
	else
		`SendSingleLineEmail "$hTemporaryFile.2" "$hFromAlias" "$hPageAlias" "$hMailSubject:LoadAvg=$hLoadAvg" "$hPageAlertTitle" "$hMessage"`
	fi
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`

elif [ "$hLoadAvg" -ge "$hLoadMailLimit" ]; then

	hMessage="Load Average [$hLoadAvg] has crossed allowed Load Average Mail Limit of [$hLoadMailLimit]"

	`WriteLogFile $hScriptLogFile "$hMessage" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	if [ "$hShowTopProcesses" -gt 0 ]; then
		`SendMultiLineEmail "$hTemporaryFile.2" "$hFromAlias" "$hMailAlias" "$hMailSubject:LoadAvg=$hLoadAvg" "$hMailAlertTitle <br> [$hMessage]" "5"` 
	else
		`SendSingleLineEmail "$hTemporaryFile.2" "$hFromAlias" "$hMailAlias" "$hMailSubject:LoadAvg=$hLoadAvg" "$hMailAlertTitle" "$hMessage"`
	fi
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`

fi

if [ -f "$hTemporaryFile.2" ]; then
	rm "$hTemporaryFile.2"
fi

# write history record
hTotalSeconds=`GetElapsedTime`
hReturn=`WriteHistoryRecord "$hCPUBusy\t$hLoadAvg\t$hConfigReadTime\t$hTotalSeconds"`

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
