#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	07-Feb-2010
#	Updation Date:	07-Feb-2010
###############################################################

# define Alert Title
hMailAlertTitle="ColdBackup [Mail Alert]"
hPageAlertTitle="ColdBackup [Page Alert]"

hParam1="$1"
hParam2="$2"

# source the main environment file
hDirName=`dirname $0`
. $hDirName/hInitialize.ksh "$0" "" ""
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

hVolumes=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "Volumes"`
hArchVolumes=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ArchVolumes"`
hRedoVolumes=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RedoVolumes"`
hCLONEPreparationVolume=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CLONEPreparationVolume"`

hCreateSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CreateSnapshotCommand"`
hRenameSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RenameSnapshotCommand"`
hDeleteSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "DeleteSnapshotCommand"`
hListSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ListSnapshotCommand"`

hRetryAttempt=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RetryAttempt"`
hRetryDelayInSeconds=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RetryDelayInSeconds"`

hOracleSID=`echo $ORACLE_SID`

# write Script Specific Details to logfile

`WriteLogFile $hScriptLogFile "SQL1:              $hSQL1                     $hNewLine" "$hDateFormat"`

`WriteLogFile $hScriptLogFile "CreateSnapshotCmd: $hCreateSnapshotCommand    $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "RenameSnapshotCmd: $hRenameSnapshotCommand    $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "DeleteSnapshotCmd: $hDeleteSnapshotCommand    $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ListSnapshotCmd:   $hListSnapshotCommand      $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Retry Attempt:     $hRetryAttempt             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "RetryDelayInSec:   $hRetryDelayInSeconds      $hNewLine" "$hDateFormat"`

`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

hVolumes="$hVolumes;$hArchVolumes;$hRedoVolumes;$hCLONEPreparationVolume"
hVolumes=`ReplaceString "$hVolumes" ";" "\n"`

if [ ! -z "$hParam1" ]; then
	hSnapshotName="$hParam1"
else
	echo "Please specify snapshot name"
	exit 1
fi

if [ ! -z "$hParam2" ]; then
	hOperation="$hParam2"
else
	hOperation="CREATE"
fi

#run SQLPlus

hSQLPlusOutput=$(RunSQLCommand "$hCredentials" "$hSQL1" "$hSQLPlusExecutable" "$hTemporaryFile")
if [ $? -eq 0 ]; then

	print "Database is RUNNING [$hSQLPlusOutput]"

fi

if [ -f "$hSQLPlusOutFile" ]; then
	rm "$hSQLPlusOutFile"
fi


if [ "$hOperation" = "CREATE" ]; then
	if [ -z "`echo "$hSQLPlusOutput"|grep "1034"`" ]; then
		print "\nDatabase is RUNNING . . ."
		$(WriteLogFile $hScriptLogFile "$hSQLPlusOutput" "$hDateFormat")
		#exit 1
	else
		print "Database is NOT RUNNING . . ."
	fi
fi


# take filer action [CREATE/DELETE/LIST]

echo "$hVolumes"|while read LINE;
do

	hFiler=`echo "$LINE"|cut -d ":" -f1`
	hVolume=`echo "$LINE"|cut -d ":" -f2`

	printf "$hOperation snapshot for $hFiler:$hVolume . . ."
	hReturn=`TakeSnap "$hFiler" "$hVolume" "$hOperation" "$hSnapshotName`
	if [ $? -eq 1 ]; then
		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to run filer command" "$hReturn"`
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
		exit 1
	fi
	print " COMPLETED [$hReturn] \n"

done

`WriteLogFile $hScriptLogFile " ColdBackup Script Completed Successfully $hNewLine" "$hDateFormat"`
