#!/bin/bash
# Author: Habib Rangoonwala
# Updated: 12-JUN-2014
# 

Server=$1
SleepTime=$2
# to support AccessGate
MODULE=$3
hFile='gcstat'
hJavaVendor=`java -version 2>&1 |grep -i jrockit`
hDIR=`dirname $0`

if [ "$hJavaVendor" = "" ]; then
        hJavaVendor="ORACLE"
else
        hJavaVendor="JROCKIT"
fi
getProcessID()
{
	#if [ "$hJavaVendor"  = "ORACLE" ]; then
	# to support AccessGate
	if [ "$hJavaVendor"  = "ORACLE" -a "$MODULE" = "" ]; then
	hPID=`adopmnctl.sh status|grep 'oacore\|c4ws\|oafm' |cut -d "|" -f 3`
	else
		   hPID=`jps|grep Server|cut -d " " -f 1`
	fi
	#echo $hPID
}

getProcessID

checkProcessID()
{
	getProcessID
	for i in $hPID
	do
		if [ ! -f /proc/$i/exe ]; then
			getProcessID
		fi
	done
}

while true
do
	for i in $hPID
	do

		TimeStamp=$(date +'%a %d-%b-%Y %T [%Z]')             
		HOSTNAME=$(hostname)
		hDatePostFix=`date "+%m_%d_%Y"`
		CpuUsage=`ps -p $i -o pcpu |tail -1`

		if [ "$hJavaVendor"  = "ORACLE" -a "$MODULE" = "" ]; then

			ServerName=$(ps hw -f -p $i | sed 's/^.*Doracle\.ons\.indexid=//; s/ .*$//')
			hOutput=`jstat -gc $i 1s 1|tail -1`
			hClasses=`jstat  -class $i 1s 1|tail -1`
			hJVMUsage=`jstat -gc $i | tail -1 |gawk '{print ($3+$4+$6+$8)/1024};'|head -1`   
			hPSMem=`ps -p $i -O rss | tail -1| gawk '{ print $2/1024 };' `
			hVmSize=`cat /proc/$i/status | grep 'VmSize' | gawk '{print ($2)};'`
			# added to support accessgate
			hThreads=`cat /proc/$i/status | grep 'Threads:' | gawk '{print ($2)};'`
			hFreeHostMem=`grep 'MemFree:' /proc/meminfo|gawk '{print ($2)};'`
			hFreeHostSwapMem=`grep 'SwapFree:' /proc/meminfo|gawk '{print ($2)};'`
			hPMAP=`pmap $i | tail -1 | gawk '{print $2};'` 

			echo "$TimeStamp  $CpuUsage $hJVMUsage $hPSMem $hVmSize $hThreads $hFreeHostMem $hFreeHostSwapMem $hPMAP $hOutput $hClasses $ServerName.$HOSTNAME" >> "$hDIR/../logs/$Server/his/$hFile.$Server.$hDatePostFix"
		else
			ServerName=$(ps hw -f -p $i | sed 's/^.*-Dweblogic\.Name=//; s/ .*$//')                  
			hOutput=`jstat -gc $i 1s 1|tail -1`
			hClasses=`jstat  -class $i 1s 1|tail -1`
			hPSMem=`ps -p $i -O rss | tail -1| gawk '{ print $2/1024 };' `
			hJVMUsage=`jstat -gc $i | tail -1 |gawk '{print ($3+$4+$6+$8)/1024};'|head -1` 
			hVmSize=`cat /proc/$i/status | grep 'VmSize' | gawk '{print ($2)};'`
			# added to support accessgate
			hThreads=`cat /proc/$i/status | grep 'Threads:' | gawk '{print ($2)};'`
			hFreeHostMem=`grep 'MemFree:' /proc/meminfo|gawk '{print ($2)};'`
			hFreeHostSwapMem=`grep 'SwapFree:' /proc/meminfo|gawk '{print ($2)};'`
			hPMAP=`pmap $i | tail -1 | gawk '{print $2};'`

			echo "$TimeStamp  $CpuUsage $hJVMUsage $hPSMem $hVmSize $hThreads $hFreeHostMem $hFreeHostSwapMem $hPMAP $hOutput $hClasses $ServerName" >> "$hDIR/../logs/$Server/his/$hFile.$Server.$hDatePostFix"               
		fi
	done

	sleep $SleepTime 

	checkProcessID

done
exit 0
