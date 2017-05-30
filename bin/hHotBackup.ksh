#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	14-Jan-2009
#	Updation Date:	14-Jan-2009 19-Feb-2009
#	Updation Date:	31-Jul-2009 [added refresh automation steps]
#	Updation Date:	05-Aug-2010 [added to remove temporary file in EndBackup section
###############################################################

# define Alert Title
hMailAlertTitle="HotBackup [Mail Alert]"
hPageAlertTitle="HotBackup [Page Alert]"

# source the main environment file
hDirName=`dirname $0`
. $hDirName/hInitialize.ksh "$0" "$1" "$2"
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
hGetCurrentSequenceSQL=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "GetCurrentSequenceSQL"`
hSQL1=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL1" "True"`
hSQL2=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQL2" "True"`

hVolumes=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "Volumes"`
hCreateSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CreateSnapshotCommand"`
hRenameSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RenameSnapshotCommand"`
hDeleteSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "DeleteSnapshotCommand"`
hListSnapshotCommand=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ListSnapshotCommand"`
hSnapshotKeepDays=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SnapshotKeepDays"`
hNamePattern=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "NamePattern" "True"`
hRetryAttempt=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RetryAttempt"`
hRetryDelayInSeconds=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "RetryDelayInSeconds"`
hSuccessFlagFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SuccessFlagFile" "True"`

hArchVolumes=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ArchVolumes"`
hArchCleanUpScript=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ArchCleanUpScript" "True"`
hArchKeepDays=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ArchKeepDays"`
hCLONEDirectory=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CLONEDirectory" "True"`
hCLONEPreparationScript=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CLONEPreparationScript" "True"`

hOracleSID=`echo $ORACLE_SID`

# Remove Success FLAG file
if [ ! -z "$hSuccessFlagFile" ]; then

	if [ -f "$hSuccessFlagFile" ]; then

		rm "$hSuccessFlagFile"
	
		if [ $? -eq 1 ]; then
			`WriteLogFile $hScriptLogFile "Unable to REMOVE[rm] SuccessFlagFile [$hSuccessFlagFile] $hNewLine" "$hDateFormat"`
			`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
			`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to remove SuccessFlagFile [$hSuccessFlagFile]" "$hOutput"`
			`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
			exit 1
		else
			`WriteLogFile $hScriptLogFile "SuccessFlagFile [$hSuccessFlagFile] REMOVED $hNewLine" "$hDateFormat"`
		fi

	fi

fi

# write Script Specific Details to logfile

`WriteLogFile $hScriptLogFile "GetCurrentSeq#SQL: $hGetCurrentSequenceSQL    $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "SQL1:              $hSQL1                     $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "SQL2:              $hSQL2                     $hNewLine" "$hDateFormat"`

`WriteLogFile $hScriptLogFile "CreateSnapshotCmd: $hCreateSnapshotCommand    $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "RenameSnapshotCmd: $hRenameSnapshotCommand    $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "DeleteSnapshotCmd: $hDeleteSnapshotCommand    $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ListSnapshotCmd:   $hListSnapshotCommand      $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Snapshot Keep Days:$hSnapshotKeepDays         $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Name Pattern:      $hNamePattern              $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "Retry Attempt:     $hRetryAttempt             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "RetryDelayInSec:   $hRetryDelayInSeconds      $hNewLine" "$hDateFormat"`

`WriteLogFile $hScriptLogFile "ArchVolumes:       $hArchVolumes              $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ArchCleanUpScript: $hArchCleanUpScript        $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ArchKeepDays:      $hArchKeepDays             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "CLONEDirectory:    $hCLONEDirectory           $hNewLine" "$hDateFormat"`

`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

hTime2=`GetElapsedTime`

hConfigReadTime=`expr $hTime2`

# function to end the backup, in case of failure, before exiting, end the backup mode.
EndBackup()
{
	# put the database in normal mode
	hOutput=`RunSQLCommand "$hCredentials" "$hSQL2" "$hSQLPlusExecutable" "$hTemporaryFile"`

	if [ $? -eq 1 ]; then
		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to end-backup" "$hOutput"`
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
		if [ -f "$hTemporaryFile" ]; then
			rm "$hTemporaryFile"
		fi
		exit 1
	fi

	if [ -f "$hTemporaryFile" ]; then
		rm "$hTemporaryFile"
	fi
	
	return 0
}

hTime1=`GetElapsedTime`

# get the current sequence
hOutput=`RunSQLCommand "$hCredentials" "$hGetCurrentSequenceSQL" "$hSQLPlusExecutable" "$hTemporaryFile"`
if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to Get Current Sequence" "$hOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
fi
hStartSequence=$hOutput

# put the database in begin backup mode
hOutput=`RunSQLCommand "$hCredentials" "$hSQL1" "$hSQLPlusExecutable" "$hTemporaryFile"`

if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to begin-backup" "$hOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
fi

hTime2=`GetElapsedTime`
hBeginBackupTime=`expr $hTime2 - $hTime1`

# backup for non-ARCH volumes

hTime1=`GetElapsedTime`

#hVolumes=`echo "$hVolumes"|tr ";" "\n"`
hVolumes=`ReplaceString "$hVolumes" ";" "\n"`
echo "$hVolumes"|while read LINE;
do

	hFiler=`echo "$LINE"|cut -d ":" -f1`
	hVolume=`echo "$LINE"|cut -d ":" -f2`

	hReturn=`TakeSnap "$hFiler" "$hVolume"`
	if [ $? -eq 1 ]; then

		EndBackup

		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to run filer command" "$hReturn"`
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
		exit 1
	fi

done

hTime2=`GetElapsedTime`
hDataVolumeBackupTime=`expr $hTime2 - $hTime1`


# put the database in normal mode

hTime1=`GetElapsedTime`

EndBackup

hTime2=`GetElapsedTime`
hEndBackupTime=`expr $hTime2 - $hTime1`

# get the current sequence
hOutput=`RunSQLCommand "$hCredentials" "$hGetCurrentSequenceSQL" "$hSQLPlusExecutable" "$hTemporaryFile"`
if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to Get Current Sequence" "$hOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
fi
hEndSequence=$hOutput


hTime1=`GetElapsedTime`

#hArchVolumes=`echo "$hArchVolumes"|tr ";" "\n"`
hArchVolumes=`ReplaceString "$hArchVolumes" ";" "\n"`
echo "$hArchVolumes"|while read LINE;
do

	hFiler=`echo "$LINE"|cut -d ":" -f1`
	hVolume=`echo "$LINE"|cut -d ":" -f2`

	hReturn=`TakeSnap "$hFiler" "$hVolume"`
	if [ $? -eq 1 ]; then
		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to run filer command" "$hReturn"`
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
		exit 1
	fi

done

hTime2=`GetElapsedTime`
hArchVolumeBackupTime=`expr $hTime2 - $hTime1`

# ARCH Clean-up
export hNewLine hMailSubject hFromAlias hMailAlias hPageAlias hLockFile hScriptLogFile hRunLogFile hScriptLogFileSize hTemporaryFile hLogDirectory
export hDateFormat hTimestamp hSQL1 hSQL2 hCryptKey hSYSDBA hCredentials hUserID hSQLPlusExecutable 
export hVolumes hCreateSnapshotCommand hRenameSnapshotCommand hDeleteSnapshotCommand hListSnapshotCommand
export hSnapshotKeepDays hNamePattern hRetryAttempt hRetryDelayInSeconds hArchVolumes hArchCleanUpScript hArchKeepDays hOracleSID hTmpStr

hTime1=`GetElapsedTime`

$hArchCleanUpScript
hArchFileDeletedCount=$?

hTime2=`GetElapsedTime`
hArchVolumeCleanupTime=`expr $hTime2 - $hTime1`


# CLONE Preparation Script Steps

hTime1=`GetElapsedTime`

export hStartSequence hEndSequence hCLONEDirectory hInstance hHost H_SCRIPTSECTION H_CONFIG_FILE

$hCLONEPreparationScript
hCLONEPreparationScriptStatus=$?

hTime2=`GetElapsedTime`
hCLONEPreparationTime=`expr $hTime2 - $hTime1`

hEndDate=`GetDate $hDateFormat`
hTotalSeconds=`GetElapsedTime`

hReturn=`WriteHistoryRecord "$hConfigReadTime\t$hBeginBackupTime\t$hDataVolumeBackupTime\t$hEndBackupTime\t$hArchVolumeBackupTime\t$hArchVolumeCleanupTime\t$hArchFileDeletedCount\t$hTotalSeconds\t$hCLONEPreparationTime"`

if [ $hCLONEPreparationScriptStatus -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - CLONEPreparationScript Failed" "$hReturn"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile " HotBackup Script Completed with WARNING $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile " HotBackup Script Completed Successfully $hNewLine" "$hDateFormat"`
fi

# Create Success FLAG file
if [ ! -z "$hSuccessFlagFile" ]; then

	touch "$hSuccessFlagFile" > $hTemporaryFile
	
	if [ $? -eq 1 ]; then
		hOutput=`cat $hTemporayFile`
		`WriteLogFile $hScriptLogFile "Unable to CREATE SuccessFlagFile [$hSuccessFlagFile] $hNewLine [$hError] $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to CREATE SuccessFlagFile [$hSuccessFlagFile] $hNewLine You can manually create SuccessFlagFile as all backup task successfully completed" "$hOutput"`
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	else
		`WriteLogFile $hScriptLogFile "SuccessFlagFile [$hSuccessFlagFile] CREATED $hNewLine" "$hDateFormat"`
	fi

fi

# PREPARE The EMail Body

echo "" > $hTemporaryFile

echo "\t\t\t***====================***"					>> $hTemporaryFile
echo "\t\t\t*** HotBackup Summary  ***"					>> $hTemporaryFile
echo "\t\t\t***====================***"					>> $hTemporaryFile
echo "========================================================="	>> $hTemporaryFile
echo "Hostname:                $H_HOSTNAME"				>> $hTemporaryFile
echo "Instance:                $hOracleSID"				>> $hTemporaryFile
echo "Backup Start Time:       $hTimestamp"				>> $hTemporaryFile
echo "Backup End Time:         $hEndDate"				>> $hTemporaryFile
echo "Configuration Read Time: $hConfigReadTime seconds"		>> $hTemporaryFile
echo "Begin Backup Time:       $hBeginBackupTime seconds"		>> $hTemporaryFile
echo "End Backup Time:         $hEndBackupTime seconds"			>> $hTemporaryFile
echo "Data Volume Backup Time: $hDataVolumeBackupTime seconds"		>> $hTemporaryFile
echo "ARCH Volume Backup Time: $hArchVolumeBackupTime seconds"		>> $hTemporaryFile
echo "ARCH Volume Cleanup Time:$hArchVolumeCleanupTime seconds"		>> $hTemporaryFile
echo "ARCH Files Deleted:      $hArchFileDeletedCount file(s)"		>> $hTemporaryFile
echo "CLONE Preparation Time:  $hCLONEPreparationTime seconds"		>> $hTemporaryFile
echo "Total Backup Time:       $hTotalSeconds seconds"			>> $hTemporaryFile
echo "========================================================="	>> $hTemporaryFile

cat $hRunLogFile >> $hTemporaryFile

#cp $hRunLogFile $hTemporaryFile

`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
`SendTextEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "SUCCESS:$hMailSubject" "$hMailAlertTitle - Log"` 
`WriteLogFile $hScriptLogFile "Alert Sent to $hMailAlias $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
