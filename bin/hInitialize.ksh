#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	30-Aug-2009
#	Updation Date:	30-Aug-2009
###############################################################
# source the main environment file
hDirName=`dirname $0`
. $hDirName/HSR.env

H_CONFIG_FILE="$H_SCRIPT_TOP/../conf/default.config.ini"

# Load the default environment before running the script.
hEnvironmentFile=`GetScriptParameter "default" "default" "DefaultSection" "EnvironmentFile" "True"`
. $hEnvironmentFile

hInstance=`GetInstance "$2"`
hHost=`GetHost "$3"`

H_CONFIG_FILE="$H_SCRIPT_TOP/../conf/default.config.ini $H_SCRIPT_TOP/../conf/$hInstance.config.ini"

H_HOSTNAME=`uname -n`
H_SCRIPTNAME=`basename $1`
H_SCRIPTSECTION=`basename $1 .ksh`

# set the environment specified in config.ini, this will ensure ORACLE_HOME, ORACLE_SID, PATH is set properly
hEnvironmentFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "EnvironmentFile" "True"`
. $hEnvironmentFile
hLogDirectory=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "LogDirectory" "True"`
hScriptLogFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ScriptLogFile" "True"`
hForce=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "Force"`

# check if the script is enabled on this instance.host, if not exit
hReturn=`IsScriptEnabled`
if [ $? -eq 1 ]; then
	if [ -f "$hScriptLogFile" ]; then
		if [ "$hForce" = "True" ]; then
			`WriteLogFile $hScriptLogFile "FORCE Running this script              $hNewLine" "$hDateFormat"`
		else
			`WriteLogFile $hScriptLogFile "Script is DISABLED              $hNewLine" "$hDateFormat"`
		fi
	fi
	if [ "$hForce" != "True" ]; then
		exit 1
	fi
fi

# Read Configuration Parameter
hNewLine=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "NewLine"`
hDateFormat=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "DateFormat"`
hTimestamp=`GetDate $hDateFormat`

hMailSubject=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailSubject" "True"`
hMailSubject=`eval echo "$hMailSubject"`
hFromAlias=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "FromAlias" "True"`
hMailAlias=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailAlias"`
hPageAlias=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "PageAlias"`

hLockFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "LockFile" "True"`
hScriptLogFileSize=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ScriptLogFileSize" "True"`
hHistoryFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "HistoryFile" "True"`
hTemporaryFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "TemporaryFile" "True"`
hRunLogFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RunLogFile" "True"`

hMailAlertTitle="$hMailAlertTitle [$hTimestamp]"
hPageAlertTitle="$hPageAlertTitle [$hTimestamp]"

# write to logfile about start of the script
hTmpStr=`Repeat "+-" 40`
`WriteLogFile $hScriptLogFile "\t\t\t ***==============================*** $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "\t\t\t ***$H_SCRIPTSECTION*** $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "\t\t\t ***==============================*** $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Instance:          $hInstance                 $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Hostname:          $H_HOSTNAME                $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Hostname2:         $hHost                     $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "EnvironmentFile:   $hEnvironmentFile          $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "DateFormat:        $hDateFormat               $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "FromAlias:         $hFromAlias                $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "MailAlias:         $hMailAlias                $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "PageAlias:         $hPageAlias                $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "LogFile:           $hScriptLogFile            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "LogFileSize:       $hScriptLogFileSize lines  $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "RunLogFile:        $hRunLogFile               $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "HistoryFile:       $hHistoryFile              $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "TemporaryFile:     $hTemporaryFile            $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "LockFile:          $hLockFile                 $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

# check if the Script is already running
hMessage=`CheckLockFile "$hLockFile" "$hScriptLogFile" "$hNewLine" "$hDateFormat"`

if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle" "$hMessage"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`
	exit 1
fi
