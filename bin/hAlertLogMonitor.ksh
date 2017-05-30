#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	27-May-2007
#	Updation Date:	02-Aug-2007
#	Updation Date:	19-Feb-2009
###############################################################

# define Alert Title
hMailAlertTitle="Alert Log Monitor [Mail Alert]"
hPageAlertTitle="Alert Log Monitor [Page Alert]"

# source the main environment file
hDirName=`dirname $0`
. $hDirName/hInitialize.ksh "$0"
if [ $? -eq 1 ]; then
	exit 1
fi

# Read Script Specific Configuration Parameter
hAlertLogFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "AlertLogFile" "True"`
hScriptReferenceFile=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "ScriptReferenceFile" "True"`

hMailKeywords=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailKeywords"`
hPageKeywords=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "PageKeywords"`

hMailKeywordsIgnoreList=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "MailKeywordsIgnoreList"`
hPageKeywordsIgnoreList=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "PageKeywordsIgnoreList"`

hDisplayFullRecord=`GetScriptParameter "$hInstance" "$hHost" "$H_SCRIPTSECTION" "DisplayFullRecord"`

hConfigReadTime=`GetElapsedTime`

# write Script Specific Details to logfile
`WriteLogFile $hScriptLogFile "AlertLogFile:      $hAlertLogFile             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "ReferenceFile:     $hScriptReferenceFile      $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "MailKeywords:      $hMailKeywords             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "MailKeywordsIgnore:$hMailKeywordsIgnoreList   $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "PageKeywords:      $hPageKeywords             $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "PageKeywordsIgnore:$hPageKeywordsIgnoreList   $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "DisplayFullRecord: $hDisplayFullRecord        $hNewLine" "$hDateFormat"`
`WriteLogFile $hScriptLogFile "$hTmpStr $hNewLine" "$hDateFormat"`

#====================================
# Check if the File exists!
#====================================
if [ -f "$hAlertLogFile" ]; then
	`WriteLogFile $hScriptLogFile "File [$hAlertLogFile] Exists $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "File [$hAlertLogFile] is missing $hNewLine" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle" "File [$hAlertLogFile] is missing."`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	exit 1
fi


#=====================================
# Get the number of lines in the file
#=====================================
hTotalLines=`wc -l "$hAlertLogFile"`

# just extract NumberOfLines from output <NoOfLines> <FileName>
hTotalLines=`echo $hTotalLines | cut -f 1 -d " "`

if [ $hTotalLines -gt 0 ]; then
	`WriteLogFile $hScriptLogFile "File [$hAlertLogFile] has $hTotalLines Lines $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "File [$hAlertLogFile] has ZERO Lines $hNewLine" "$hDateFormat"`

	`WriteLogFile $hScriptLogFile "Sending Alert to $hMailAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle" "File [$hAlertLogFile] has ZERO Lines."`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	exit 1
fi

#===========================================================
# Check for Reference File with line count from previous run
#===========================================================

hPreviousLineCount=0

if [ -f $hScriptReferenceFile ]; then
	`WriteLogFile $hScriptLogFile "ScriptReferenceFile [$hScriptReferenceFile] Exists and its Writable $hNewLine" "$hDateFormat"`
	hPreviousLineCount=`cat $hScriptReferenceFile`
	`WriteLogFile $hScriptLogFile "ScriptReferenceFile Previous Line Count is $hPreviousLineCount $hNewLine" "$hDateFormat"`
else
	`WriteLogFile $hScriptLogFile "Creating ScriptReferenceFile [$hScriptReferenceFile] $hNewLine" "$hDateFormat"`
	# creating Script Reference File and redirecting the error message to TempFile
	(echo $hPreviousLineCount > $hScriptReferenceFile) 2> $hTemporaryFile

	if [ $? -gt 0 ]; then

		hMailErrorMessage=`cat $hTemporaryFile`
		`WriteLogFile $hScriptLogFile "Unable to Create ScriptReferenceFile [$hScriptReferenceFile] $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "OS Error Message [$hMailErrorMessage] $hNewLine" "$hDateFormat"`
		
		`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
		`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle" "Unable to Create ScriptReferenceFile [$hScriptReferenceFile]" "OS Error Message [$hMailErrorMessage]"`
		`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`
		
		exit 1
	else
		`WriteLogFile $hScriptLogFile "Created ScriptReferenceFile [$hScriptReferenceFile] $hNewLine" "$hDateFormat"`
	fi
fi

#==========================================
# Update Reference File with new line count
#==========================================

(echo $hTotalLines > $hScriptReferenceFile) 2> $hTemporaryFile
if [ $? -ne 0 ]; then

	hMailErrorMessage=`cat $hTemporaryFile`
	`WriteLogFile $hScriptLogFile "Unable Reset ScriptReferenceFile [$hScriptReferenceFile] $hNewLine" "$hDateFormat"`
	`WriteLogFile $hScriptLogFile "OS Error Message [$hMailErrorMessage] $hNewLine" "$hDateFormat"`	

	`WriteLogFile $hScriptLogFile "Sending Alert to $hPageAlias $hNewLine" "$hDateFormat"`
	`SendSingleLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle" "Unable Reset ScriptReferenceFile [$hScriptReferenceFile]" "OS Error Message [$hMailErrorMessage]"`
	`WriteLogFile $hScriptLogFile "Alert Sent to $hPageAlias $hNewLine" "$hDateFormat"`

	exit 1
fi

#=================================================================
# Find out how many lines needs to be processed in alert.log file
#=================================================================
hNewLines=0
if [ $hTotalLines -ge $hPreviousLineCount ]; then
	hNewLines=`expr $hTotalLines - $hPreviousLineCount`
else
	hNewLines=$hTotalLines
fi


#====================
# Process  new lines
#====================

# declare an array to store all the lines from last run

hAlertLogLines=""
hMailErrorMessage=""
hPageErrorMessage=""
hTimeStampLine=""

hMailErrorCount=0
hPageErrorCount=0

if [ $hNewLines -eq 0 ]; then
	`WriteLogFile $hScriptLogFile "No New Lines to be processed $hNewLine" "$hDateFormat"`
else

	`WriteLogFile $hScriptLogFile "Number of Lines to be processed = $hNewLines $hNewLine" "$hDateFormat"`
	hTmpCount=0

	# read all the lines to be processed
	# also write it to history file
	hAlertLogText=`tail -$hNewLines $hAlertLogFile`
	echo "$hAlertLogText" | while read LINE;
	do
		hAlertLogLines[$hTmpCount]="$LINE"
		hTmpCount=`expr $hTmpCount + 1`

		hTmpString=`echo $LINE | cut -f 1 -d " "`

		if [ ! -z `echo "Sun Mon Tue Wed Thu Fri Sat"|grep "$hTmpString"` ]; then
			hTimeStampLine="$LINE"
		fi

		for hKeyword in $hMailKeywords;
		do

			hLine=`echo $LINE | grep -i $hKeyword`

			# write history record
			if [ ! -z "$hLine" ]; then
				hReturn=`WriteHistoryRecord "$hTimeStampLine\t$hLine"`
				break
			fi

		done

	done
	
	
	# loop thru each MailKeywords
	# +-+-+-+-+-+-+-+-+-+-+-+-+-+
	
	`WriteLogFile $hScriptLogFile "Scanning file for MailKeywords $hNewLine" "$hDateFormat"`
	
	hTmpCount=0
	while [ $hTmpCount -lt $hNewLines ]
	do
	
		for hKeyword in $hMailKeywords;
		do

			hLine=`echo ${hAlertLogLines[$hTmpCount]} | grep -i $hKeyword`

			# check if the its listed in ignore keyword			
			if [ ! -z "$hMailKeywordsIgnoreList" -a ! -z "$hLine" ]; then
			
				for hIgnoreKeyword in $hMailKeywordsIgnoreList;
				do
					hLine=`echo $hLine | grep -iv $hIgnoreKeyword`
				done

				if [ -z "$hLine" ]; then
					`WriteLogFile $hScriptLogFile "IGNORED:${hAlertLogLines[$hTmpCount]} " "$hDateFormat"`
				fi

			fi
			
			# check if the keyword exist in the alert line
			if [ ! -z "$hLine" ]; then
			
				# check if full record needs to be printed, i.e. from timestamp to timestamp
				if [ "$hDisplayFullRecord" = "True" -o "$hDisplayFullRecord" = "true" ]; then
				
					hTmpNumber=$hTmpCount
					
					# loop to navigate to the timestamp
					while true
					do

						if [ $hTmpNumber -le 0 ]; then
							break
						fi
					
						hTmpNumber=`expr $hTmpNumber - 1`

						hTmpString=`echo ${hAlertLogLines[$hTmpNumber]} | cut -f 1 -d " "`
						
						if [ -z `echo "Sun Mon Tue Wed Thu Fri Sat"|grep "$hTmpString"` ]; then
						
							if [ $hTmpNumber -le 0 ]; then
								break
							fi
							
						else
							break
						fi
					
					done
				
					# loop to extract all the record lines i.e. from timestamp to next timestamp
					
					hMailErrorMessage[$hMailErrorCount]='___BEGIN___'
					hMailErrorCount=`expr $hMailErrorCount + 1`
					
					while true
					do
					
						hMailErrorMessage[$hMailErrorCount]="${hAlertLogLines[$hTmpNumber]}"
						hAlertLineNo=`expr $hPreviousLineCount + $hTmpNumber + 1`
						`WriteLogFile $hScriptLogFile "* Line#$hAlertLineNo [${hAlertLogLines[$hTmpNumber]}] * $hNewLine" "$hDateFormat"`
						hTmpNumber=`expr $hTmpNumber + 1`
						hMailErrorCount=`expr $hMailErrorCount + 1`
						
						hTmpString=`echo ${hAlertLogLines[$hTmpNumber]} | cut -f 1 -d " "`
						
						if [ ! -z `echo "Sun Mon Tue Wed Thu Fri Sat"|grep "$hTmpString"` ]; then
							break
						else
							if [ $hTmpNumber -ge $hNewLines ]; then
								break
							fi
						fi
						
					done

					hMailErrorMessage[$hMailErrorCount]='___END___'
					hMailErrorCount=`expr $hMailErrorCount + 1`

					hTmpCount=$hTmpNumber
				
				else
				
					# when only single error line is required in email

					hMailErrorMessage[$hMailErrorCount]='___BEGIN___'
					hMailErrorCount=`expr $hMailErrorCount + 1`
				
					hMailErrorMessage[$hMailErrorCount]="$hLine"
					hMailErrorCount=`expr $hMailErrorCount + 1`

					hMailErrorMessage[$hMailErrorCount]='___END___'
					hMailErrorCount=`expr $hMailErrorCount + 1`

					hAlertLineNo=`expr $hPreviousLineCount + $hTmpCount + 1`
					`WriteLogFile $hScriptLogFile "* Line#$hAlertLineNo [$hLine] * $hNewLine" "$hDateFormat"`
				fi
			fi
			

		done

		hTmpCount=`expr $hTmpCount + 1`

	done
	
	if [ $hMailErrorCount -eq 0 ]; then
		`WriteLogFile $hScriptLogFile "No Mail Errors Found $hNewLine" "$hDateFormat"`
	else
		`WriteLogFile $hScriptLogFile "Total Mail Errors Count is $hMailErrorCount $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Sending MailAlert to $hMailAlias" "$hDateFormat"`

		hTmpCount=0
		
		# truncate Temporary File
		echo "Error Messages" > $hTemporaryFile
		
		while [ $hTmpCount -lt $hMailErrorCount ];
		do
		
			if [ "${hMailErrorMessage[$hTmpCount]}" != "___BEGIN___" -a "${hMailErrorMessage[$hTmpCount]}" != "___END___" ]; then
				printf "${hMailErrorMessage[$hTmpCount]}___NEWLINE___" >> $hTemporaryFile
			fi
			if [ "${hMailErrorMessage[$hTmpCount]}" = "___END___" ]; then
				echo "$hNewLine" >> $hTemporaryFile
			fi
			
			hTmpCount=`expr $hTmpCount + 1`
		
		done
		
		# send alert
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hMailAlias" "$hMailSubject" "$hMailAlertTitle"`
		`WriteLogFile $hScriptLogFile "MailAlert sent to $hMailAlias" "$hDateFormat"`
		
	fi
	
	
	# loop thru each PageKeywords
	# +-+-+-+-+-+-+-+-+-+-+-+-+-+
	
	`WriteLogFile $hScriptLogFile "Scanning file for PageKeywords $hNewLine" "$hDateFormat"`
	
	hTmpCount=0
	while [ $hTmpCount -lt $hNewLines ]
	do
	
		for hKeyword in $hPageKeywords;
		do

			hLine=`echo ${hAlertLogLines[$hTmpCount]} | grep -i $hKeyword|grep -iv ora-00060`

			# check if the its listed in ignore keyword			
			if [ ! -z "$hPageKeywordsIgnoreList" -a ! -z "$hLine" ]; then
			
				for hIgnoreKeyword in $hPageKeywordsIgnoreList;
				do
					hLine=`echo $hLine | grep -iv $hIgnoreKeyword`
				done
				
				if [ -z "$hLine" ]; then
					`WriteLogFile $hScriptLogFile "IGNORED:${hAlertLogLines[$hTmpCount]} " "$hDateFormat"`
				fi
				
			fi
			
			# check if the keyword exist in the alert line
			if [ ! -z "$hLine" ]; then
			
				# check if full record needs to be printed, i.e. from timestamp to timestamp
				if [ "$hDisplayFullRecord" = "True" -o "$hDisplayFullRecord" = "true" ]; then
				
					hTmpNumber=$hTmpCount
					
					# loop to navigate to the timestamp
					while true
					do

						if [ $hTmpNumber -le 0 ]; then
							break
						fi
					
						hTmpNumber=`expr $hTmpNumber - 1`

						hTmpString=`echo ${hAlertLogLines[$hTmpNumber]} | cut -f 1 -d " "`
						
						if [ -z `echo "Sun Mon Tue Wed Thu Fri Sat"|grep "$hTmpString"` ]; then
						
							if [ $hTmpNumber -le 0 ]; then
								break
							fi
							
						else
							break
						fi
					
					done
				
					# loop to extract all the record lines i.e. from timestamp to next timestamp

					hPageErrorMessage[$hPageErrorCount]='___BEGIN___'
					hPageErrorCount=`expr $hPageErrorCount + 1`

					while true
					do
						
						hPageErrorMessage[$hPageErrorCount]="${hAlertLogLines[$hTmpNumber]}"
						hAlertLineNo=`expr $hPreviousLineCount + $hTmpNumber + 1`
						`WriteLogFile $hScriptLogFile "* Line#$hAlertLineNo [${hAlertLogLines[$hTmpNumber]}] * $hNewLine" "$hDateFormat"`
						hTmpNumber=`expr $hTmpNumber + 1`
						hPageErrorCount=`expr $hPageErrorCount + 1`
						
						hTmpString=`echo ${hAlertLogLines[$hTmpNumber]} | cut -f 1 -d " "`
						
						if [ ! -z `echo "Sun Mon Tue Wed Thu Fri Sat"|grep "$hTmpString"` ]; then
							break
						else
							if [ $hTmpNumber -ge $hNewLines ]; then
								break
							fi
						fi
						
					done

					hPageErrorMessage[$hPageErrorCount]='___END___'
					hPageErrorCount=`expr $hPageErrorCount + 1`
					
					hTmpCount=$hTmpNumber
				
				else
				
					# when only single error line is required in email

					hPageErrorMessage[$hPageErrorCount]='___BEGIN___'
					hPageErrorCount=`expr $hPageErrorCount + 1`
				
					hPageErrorMessage[$hPageErrorCount]="$hLine"
					hPageErrorCount=`expr $hPageErrorCount + 1`

					hPageErrorMessage[$hPageErrorCount]='___END___'
					hPageErrorCount=`expr $hPageErrorCount + 1`


					hAlertLineNo=`expr $hPreviousLineCount + $hTmpCount + 1`
					`WriteLogFile $hScriptLogFile "* Line#$hAlertLineNo [$hLine] * $hNewLine" "$hDateFormat"`
				fi
			fi
			

		done

		hTmpCount=`expr $hTmpCount + 1`

	done
	
	
	if [ $hPageErrorCount -eq 0 ]; then
		`WriteLogFile $hScriptLogFile "No Page Errors Found $hNewLine" "$hDateFormat"`
	else
		`WriteLogFile $hScriptLogFile "Total Page Errors Count is $hPageErrorCount $hNewLine" "$hDateFormat"`
		`WriteLogFile $hScriptLogFile "Sending PageAlert to $hPageAlias" "$hDateFormat"`
		
		hTmpCount=0
		
		# truncate Temporary File
		echo "Error Messages" > $hTemporaryFile
		
		while [ $hTmpCount -lt $hPageErrorCount ];
		do

			if [ "${hPageErrorMessage[$hTmpCount]}" != "___BEGIN___" -a "${hPageErrorMessage[$hTmpCount]}" != "___END___" ]; then
				printf "${hPageErrorMessage[$hTmpCount]}___NEWLINE___" >> $hTemporaryFile
			fi
			
			if [ "${hPageErrorMessage[$hTmpCount]}" = "___END___" ]; then
				echo "$hNewLine" >> $hTemporaryFile
			fi
			
			hTmpCount=`expr $hTmpCount + 1`
		
		done

		# send alert
		`SendMultiLineEmail "$hTemporaryFile" "$hFromAlias" "$hPageAlias" "$hMailSubject" "$hPageAlertTitle"`
		`WriteLogFile $hScriptLogFile "PageAlert sent to $hPageAlias" "$hDateFormat"`
	
	fi

fi

`WriteLogFile $hScriptLogFile "Script completed $hNewLine" "$hDateFormat"`

# truncate log file <hScriptLogFileSize> lines
tail "-$hScriptLogFileSize" $hScriptLogFile > $hTemporaryFile
mv $hTemporaryFile $hScriptLogFile
exit 0
