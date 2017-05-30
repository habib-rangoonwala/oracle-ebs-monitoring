#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	24-Feb-2009
#	Updation Date:	24-Feb-2009
###############################################################

# source the main environment file
hDirName=`dirname $0`
. $hDirName/HSR.env

# Load the default environment before running the script.
hEnvironmentFile=`GetScriptParameter "default" "default" "DefaultSection" "EnvironmentFile" "True"`
. $hEnvironmentFile

hInstance=`GetInstance`
hHost=`GetHost`

hHostname=`uname -n`
HOSTNAME=$hHostname
SCRIPT_NAME=`basename $0 .ksh`

hRequestID=$1

# set the environment specified in config.ini, this will ensure ORACLE_HOME, ORACLE_SID, PATH is set properly
hEnvironmentFile=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "EnvironmentFile" "True"`
. $hEnvironmentFile

# check if the script is enabled on this instance.host, if not exit
hReturn=`IsScriptEnabled`
if [ $? -eq 1 ]; then
	exit 1
fi

# Read Configuration Parameter
hNewLine=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "NewLine"`
hMailSubject=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "MailSubject" "True"`

hFromAlias=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "FromAlias" "True"`
hMailAlias=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "MailAlias"`
hPageAlias=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "PageAlias"`

hLockFile=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "LockFile" "True"`
hScriptLogFile=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "ScriptLogFile" "True"`
hScriptLogFileSize=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "ScriptLogFileSize" "True"`
hHistoryFile=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "HistoryFile" "True"`

hTemporaryFile=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "TemporaryFile" "True"`

hDateFormat=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "DateFormat"`

hTimestamp=`GetDate $hDateFormat`

#hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "SQL1"`
hCryptKey=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "CryptKey"`
hSYSDBA=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "SYSDBA"`
hCredentials=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "Credentials" "True"`
hUserID=""
hSQLPlusExecutable=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "SQLPlusExecutable" "True"`
hSQLPlusOutFile=`GetScriptParameter "$hInstance" "$hHost" "$SCRIPT_NAME" "SQLPlusOutFile" "True"`


hSQL1="
SELECT *
FROM
(
SELECT	fcr.request_id||CHR(9)||
	fcp.concurrent_program_name||CHR(9)||
	fcpt.user_concurrent_program_name||CHR(9)||
	TO_CHAR(fcr.actual_start_date,'DD-MON-RRRR HH24:MI')||CHR(9)||
	TO_CHAR(fcr.actual_completion_date,'DD-MON-RRRR HH24:MI')||CHR(9)||
	ROUND(((fcr.actual_completion_date - fcr.actual_start_date)* 24 * 60),2)||CHR(9)||
	ROUND(((fcr.actual_start_date - fcr.requested_start_date)* 24 * 60),2)||CHR(9)||
	fcr.argument_text
FROM	apps.fnd_concurrent_requests fcr,
	apps.fnd_concurrent_programs fcp,
	apps.fnd_concurrent_programs_tl fcpt,
	apps.fnd_concurrent_processes fcpro
WHERE	fcr.program_application_id = fcp.application_id
AND	fcr.concurrent_program_id  = fcp.concurrent_program_id 
AND	fcp.application_id = fcpt.application_id
AND	fcp.concurrent_program_id = fcpt.concurrent_program_id
AND	fcr.Controlling_Manager = fcpro.Concurrent_Process_ID
AND	fcp.concurrent_program_name=
	(
		SELECT	concurrent_program_name
		FROM	apps.fnd_concurrent_requests fcr,apps.fnd_concurrent_programs fcp
		WHERE	fcr.program_application_id = fcp.application_id
		AND	fcr.concurrent_program_id  = fcp.concurrent_program_id 
		AND	fcr.request_id = $hRequestID
	)
ORDER	BY
	fcr.actual_start_date DESC
)
WHERE	ROWNUM < 11
"


# write to logfile about start of the script
#hTmpStr=`Repeat "+-" 40`
#`WriteLogFile $hScriptLogFile "\t\t\t ***=================*** $hNewLine" "$hDateFormat"`
#`WriteLogFile $hScriptLogFile "\t\t\t *** GetRequestIDInfo*** $hNewLine" "$hDateFormat"`
#`WriteLogFile $hScriptLogFile "\t\t\t ***=================*** $hNewLine" "$hDateFormat"`
#`WriteLogFile $hScriptLogFile "$hNewLine" "$hDateFormat"`

hMailSubject=`eval echo "$hMailSubject"`

# check if the Script is already running

hMessage=`CheckLockFile "$hLockFile" "$hScriptLogFile" "$hNewLine" "$hDateFormat"`

if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "FAILED:$hMailSubject" "GetRequestIDInfo [$hTimestamp] [Mail Alert]" "$hMessage"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
	exit 1
fi

# decrypt the credentials

hCredentials=`GetSQLCredentials "$hCryptKey" "$hSYSDBA" "$hCredentials"`

if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "$hCredentials $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "GetRequestIDInfo [$hTimestamp] [Page Alert]" "Unable to decrypt credentials [$hCredentials]"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
fi


#run SQLPlus

hSQLPlusOutput=`RunSQLCommand "$hCredentials" "$hSQL1" "$hSQLPlusExecutable" "$hTemporaryFile"`

if [ $? -eq 1 ]; then

	`WriteLogFile $hScriptLogFile "Following error occurred $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "GetRequestIDInfo [$hTimestamp] [Page Alert]" "$hSQLPlusOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	exit 1

fi

cat "$hSQLPlusOutFile"|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		#hRequestID=`printf "%s" "$LINE" |awk 'BEGIN {FS="\t"} {print $1}'`
		#hConcurrentProgramName=`printf "%s" "$LINE" |awk 'BEGIN {FS="\t"} {print $2}'`
		#hUserConcurrentProgramName=`printf "%s" "$LINE"|awk 'BEGIN {FS="\t"} {print $3}'`
		#hActualStartTime=`printf "%s" "$LINE"|awk 'BEGIN {FS="\t"} {print $4}'`
		#hActualCompletionTime=`printf "%s" "$LINE"|awk 'BEGIN {FS="\t"} {print $5}'`
		#hExecutionTime=`printf "%s" "$LINE"|awk 'BEGIN {FS="\t"} {print $6}'`
		#hWaitTime=`printf "%s" "$LINE"|awk 'BEGIN {FS="\t"} {print $7}'`
		#hParameter=`printf "%s" "$LINE"|awk 'BEGIN {FS="\t"} {print $8}'`

		hRequestID=`GetColumnValue "$LINE" "1"`
		hConcurrentProgramName=`GetColumnValue "$LINE" "2"`
		hUserConcurrentProgramName=`GetColumnValue "$LINE" "3"`
		hActualStartTime=`GetColumnValue "$LINE" "4"`
		hActualCompletionTime=`GetColumnValue "$LINE" "5"`
		hExecutionTime=`GetColumnValue "$LINE" "6"`
		hWaitTime=`GetColumnValue "$LINE" "7"`
		hParameter=`GetColumnValue "$LINE" "8"`

	fi
	
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$hRequestID $hConcurrentProgramName $hUserConcurrentProgramName $hActualStartTime $hActualCompletionTime $hExecutionTime $hWaitTime"

done


#`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
#tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
#mv $hTemporaryFile $hScriptLogFile
exit 0

