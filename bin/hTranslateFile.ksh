#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	05-Aug-2009
###############################################################

# source the main environment file
hDirName=`dirname $0`
. $hDirName/HSR.env

hSourceUpper=`ToUpper $1`
hTargetUpper=`ToUpper $2`

hSourceLower=`ToLower $1`
hTargetLower=`ToLower $2`

# sourcing the source environment ini
. $hDirName/$hSourceUpper.source.ini

TMPFILE=`mktemp`

cat $hDirName/hTranslateFile.ini|grep -v '^#'|while read LINE;
do

	if [ ! -z "$LINE" ]; then

		#hSource=`echo "$LINE"|awk -F= '{print $1}'`
		#hTarget=`echo "$LINE"|awk -F= '{print $2}'`

		hSource=$(echo "$LINE"|cut -d "=" -f1)
		hTarget=$(echo "$LINE"|cut -d "=" -f2)

		sudo cp "$hSource" "$hTarget"

		cat $hDirName/$hTargetUpper.target.ini|grep -v '^#'|while read LINE2;
		do
	
			if [ ! -z "$LINE2" ]; then
			
				hSTR=$(MyEval "$LINE2")

				hCMD="sudo sed -e 's!"$hSTR"!g' $hTarget"
				echo "$hCMD > $TMPFILE" > /tmp/h.sh
				sh /tmp/h.sh
				sudo mv "$TMPFILE" "$hTarget"
			
			fi

		done

	fi

done

#sed -e "s|$hSourceUpper|$hTargetUpper|g" -e "s|$hSourceLower|$hTargetLower|g" $ORACLE_HOME/dbs/initORCL.ora

exit 0

#/HSR_SCRIPTS/hScripts/hTranslateFile.ksh ORCL NEWORCL 
