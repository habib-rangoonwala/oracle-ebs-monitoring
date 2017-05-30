#!/bin/ksh
###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	27-May-2007
#	Updation Date:	02-Aug-2007
###############################################################

# source the main environment file
hDirName=`dirname $0`
. $hDirName/HSR.env

hHour=`date +"%H"`
if [ "$hHour" = "00" -o "$hHour" = "04" -o "$hHour" = "08" -o "$hHour" = "12" -o "$hHour" = "16" -o "$hHour" = "20" ]; then
	$hDirName/hZombieMonitor.ksh
	wait
fi

$hDirName/hOSMonitor.ksh
wait
$hDirName/hRunawayMonitor.ksh &
wait

# DB Specific Scripts
$hDirName/hAlertLogMonitor.ksh &
wait
$hDirName/hTSMonitor.ksh &
wait
$hDirName/hDBSessionMonitor.ksh &
wait
$hDirName/hLockMonitor.ksh &
wait
$hDirName/hTempTSMonitor.ksh &
wait
$hDirName/hUNDOTSMonitor.ksh &
wait

# CM Tier Specific Scripts
$hDirName/hCMQueueMonitor.ksh &
wait
$hDirName/hSFMQueueMonitor.ksh &
wait
$hDirName/hWFQueueMonitor.ksh &
wait
$hDirName/hWFInBoundMailMonitor.ksh &
wait

# URL Monitoring
$hDirName/hURLMonitor.ksh &
wait
