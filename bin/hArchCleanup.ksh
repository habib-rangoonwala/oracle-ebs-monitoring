#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	30-Jan-2009
#	Updation Date:	30-Jan-2009
#	Updation Date:	07-Feb-2010 [Fixed hArchSQL1, where LOCATION is written in mix characters like upper/lower
#	This script cannot be run individually, it should be 
#	invoked by hHotBackup.ksh script
###############################################################

# source the main environment file
hDirName=`dirname $0`
. $hDirName/HSR.env

#hArchSQL1="SELECT REPLACE(value,'location=') FROM v\$parameter WHERE name LIKE 'log_archive_dest%' AND name NOT LIKE 'log_archive_dest%state%'"
# above SQL doesnt work with upper case LOCATION, fixed it as below
hArchSQL1="SELECT SUBSTR(value,INSTR(value,'=')+1) FROM v\$parameter WHERE name LIKE 'log_archive_dest%' AND name NOT LIKE 'log_archive_dest%state%'"
hArchSQL2="SELECT SUBSTR(value,1,INSTR(value,'%')-1)||'*'||SUBSTR(value,INSTR(value,'.')) FROM v\$parameter WHERE name='log_archive_format'"

hOutput=`RunSQLCommand "$hCredentials" "$hArchSQL1" "$hSQLPlusExecutable" "$hTemporaryFile"`
hLogArchiveFormat=`RunSQLCommand "$hCredentials" "$hArchSQL2" "$hSQLPlusExecutable" "$hTemporaryFile"`

echo "$hOutput"|while read hARCHDEST;
do

	if [ ! -z $hARCHDEST ]; then
		hArchRMCommand="find  $hARCHDEST/* -name $hLogArchiveFormat  -mtime +$hArchKeepDays -exec ls -ltr {}"
		`WriteLogFile $hScriptLogFile "Command being run [$hArchRMCommand] $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Following ARCH files are being DELETED[$hARCHDEST/$hLogArchiveFormat]: $hNewLine" "$hDateFormat"`
		hArchFileList=`find  $hARCHDEST/* -name $hLogArchiveFormat  -mtime +$hArchKeepDays -exec ls -ltr {} \;`
		if [ ! -z "$hArchFileList" ]; then
			hArchFileCount=`echo "$hArchFileList"|wc -l`
		else
			hArchFileCount=0
		fi
		`WriteLogFile $hScriptLogFile "$hArchFileList $hNewLine" "$hDateFormat"`
		hArchFileList=`find  $hARCHDEST/* -name $hLogArchiveFormat  -mtime +$hArchKeepDays -exec rm {} \;`
		`WriteLogFile $hScriptLogFile "RM Output:$hArchFileList $hNewLine" "$hDateFormat"`
	fi

done

exit $hArchFileCount
