#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	02-Sep-2009
#	Updation Date:	02-Sep-2009
###############################################################

hCredentials=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "Credentials" "True"`
hSQLPlusExecutable=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQLPlusExecutable" "True"`
hCryptKey=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "CryptKey"`
hSYSDBA=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SYSDBA"`
hSQLPlusOutFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "SQLPlusOutFile" "True"`

`WriteLogFile $hScriptLogFile "SQLPlusExecutable: $hSQLPlusExecutable        $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "SQLPlusOutFile:    $hSQLPlusOutFile           $hNewLine" "$hDateFormat"`

# decrypt the credentials

hCredentials=`GetSQLCredentials "$hCryptKey" "$hSYSDBA" "$hCredentials"`

if [ $? -eq 1 ]; then
	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "$hCredentials $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "FAILED:$hMailSubject" "$hPageAlertTitle" "Unable to decrypt credentials [$hCredentials]"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
	exit 1
fi
