#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	31-Jul-2009
#	Updation Date:	31-Jul-2009
#	Updation Date:	07-Feb-2010 [fixed CLONEDirectory, multiple ARCHDEST causes duplicate files, hardcoded dest_id=1 in SQL1 and SQL3
#
#	This script cannot be run individually, it should be 
#	invoked by hHotBackup.ksh script
###############################################################

# source the main environment file
hDirName=`dirname $0`
. $hDirName/HSR.env

`WriteLogFile $hScriptLogFile "*** Running CLONE Preparation Script *** $hNewLine" "$hDateFormat"`

hCLONEControlFile="$hCLONEDirectory/hCLONEControlFile.sql"

if [ ! -d "$hCLONEDirectory" ]; then
	mkdir -p "$hCLONEDirectory"

	`WriteLogFile $hScriptLogFile "Created $hCLONEDirectory $hNewLine" "$hDateFormat"`
fi

# script to generate recovery control file script
hControlFileSQL="ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS '$hCLONEControlFile' REUSE RESETLOGS"
hOutput=`RunSQLCommand "$hCredentials" "$hControlFileSQL" "$hSQLPlusExecutable" "$hTemporaryFile"`
if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to generate BACKUP CONTROLFILE" "$hOutput"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
fi

# include SET database in control file sql script
sed -e "s/CREATE CONTROLFILE REUSE/CREATE CONTROLFILE REUSE SET/" "$hCLONEControlFile" > "$hCLONEControlFile.2"
mv "$hCLONEControlFile.2" "$hCLONEControlFile"

# add UNTIL CANCEL in control file sql script
sed -e "s/RECOVER DATABASE USING BACKUP CONTROLFILE/RECOVER DATABASE USING BACKUP CONTROLFILE UNTIL CANCEL/" "$hCLONEControlFile" > "$hCLONEControlFile.2"
mv "$hCLONEControlFile.2" "$hCLONEControlFile"


# script to copy ARCH files to RECOVERY destination

hArchSQL1="SELECT name FROM v\$archived_log WHERE sequence# BETWEEN $hStartSequence AND $hEndSequence AND dest_id=1 AND resetlogs_change# = (SELECT resetlogs_change# FROM v\$database) ORDER BY name"
hArchSQL2="SELECT SUBSTR(value,1,INSTR(value,'%')-1)||'*'||SUBSTR(value,INSTR(value,'.')) FROM v\$parameter WHERE name='log_archive_format'"
hArchSQL3="SELECT REPLACE(name,(SELECT value FROM v\$parameter WHERE name='log_archive_dest'),'$hCLONEDirectory') FROM v\$archived_log WHERE sequence# BETWEEN $hStartSequence AND $hEndSequence AND dest_id=1 ORDER BY name"

hArchFileList=`RunSQLCommand "$hCredentials" "$hArchSQL1" "$hSQLPlusExecutable" "$hTemporaryFile"`
hArchFileList2=`RunSQLCommand "$hCredentials" "$hArchSQL3" "$hSQLPlusExecutable" "$hTemporaryFile"`
hLogArchiveFormat=`RunSQLCommand "$hCredentials" "$hArchSQL2" "$hSQLPlusExecutable" "$hTemporaryFile"`

hRMList=`ls -ltr $hCLONEDirectory/$hLogArchiveFormat`
`WriteLogFile $hScriptLogFile "Following CLONED-ARCH files from previous run are being DELETED[$hCLONEDirectory]: $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hRMList $hNewLine" "$hDateFormat"`
hRMOuput=`rm $hCLONEDirectory/$hLogArchiveFormat`
`WriteLogFile $hScriptLogFile "RM Output: $hRMOutput $hNewLine" "$hDateFormat"`

`WriteLogFile $hScriptLogFile "STARTING ARCH File COPY to CLONEDirectory=$hCLONEDirectory $hNewLine" "$hDateFormat"`

echo "$hArchFileList"|while read hArchFile;
do

	if [ ! -z $hArchFile ]; then
		`WriteLogFile $hScriptLogFile "Copying $hArchFile to $hCLONEDirectory $hNewLine" "$hDateFormat"`
		hCPOutput=`cp $hArchFile $hCLONEDirectory`
		hCPStatus=$?
		if [ $hCPStatus -eq 0 ]; then
			`WriteLogFile $hScriptLogFile "ARCH File Copy SUCCESS $hNewLine" "$hDateFormat"`
		else
			`WriteLogFile $hScriptLogFile "ARCH File Copy FAILED [$hCPOutput] $hNewLine" "$hDateFormat"`
			exit 1
		fi
	fi

done

`WriteLogFile $hScriptLogFile "Successfully COPIED from Seq#$hStartSequence To Seq#$hEndSequence $hNewLine" "$hDateFormat"`

# add the list of ARCH files to control file sql script
#sed -e "s/$/\\\/" hsr.txt ## to add "\" at the end of the line

> "$hCLONEControlFile.2"

cat "$hCLONEControlFile"|while read LINE;
do

	# alternatively we can use    """sed -e '/^$/d' hCLONEControlFile.sql > h.sql""""
	if [ ! -z "$LINE" ]; then
		echo "$LINE" >> "$hCLONEControlFile.2"
	fi

	if [ "$LINE" = "RECOVER DATABASE USING BACKUP CONTROLFILE UNTIL CANCEL" ]; then
		echo "$hArchFileList2" >> "$hCLONEControlFile.2"
		echo "CANCEL" >> "$hCLONEControlFile.2"
	fi

done

mv "$hCLONEControlFile.2" "$hCLONEControlFile"

if [ $? -eq 0 ]; then
	`WriteLogFile $hScriptLogFile "Successfully UPDATED BACKUP CONTROLFILE with ARCH file Information $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "Unable to update BACKUP CONTROLFILE with ARCH file Information $hNewLine" "$hDateFormat"`
fi

# take CLONEPreparationVolume Snapshot
hCLONEPreparationVolume=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CLONEPreparationVolume"`

if [ ! -z "$hCLONEPreparationVolume" ]; then

	hFiler=`echo "$hCLONEPreparationVolume"|cut -d ":" -f1`
	hVolume=`echo "$hCLONEPreparationVolume"|cut -d ":" -f2`

	hReturn=`TakeSnap "$hFiler" "$hVolume"`
	if [ $? -eq 1 ]; then

		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle - Unable to run filer command" "$hReturn"`
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
		exit 1
	fi
	
else

	`WriteLogFile $hScriptLogFile "CLONEPreparationVolume NOT Defined $hNewLine" "$hDateFormat"`

fi

exit 0