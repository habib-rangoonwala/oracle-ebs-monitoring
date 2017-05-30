#!/bin/bash
# Author: Habib Rangoonwala
# Updated: 14-SEP-2012
# Provides information about one Java PID, RSS [Resident Set Size], Heap Utilization, memory using pmap.



printf "TimeStamp \t\t\t\t Process Mem \t\t JVMUsage \t\t hPMAP \n"

while true
do

        hTimeStamp=`date`
        hPSMem=`ps -p $1 -O rss | tail -1| gawk '{ print $2/1024 };' `
        hJVMUsage=`jstat -gc $1 | tail -1 |gawk '{print ($3+$4+$6+$8)/1024};'|head -1`
        hPMAP=`pmap $1 | tail -1 | gawk '{print $2};'`

        printf "$hTimeStamp \t\t\t $hPSMem \t\t $hJVMUsage \t\t $hPMAP \n"

        sleep 1

done
exit 0

#ps -C $1 -O rss | gawk '{ count ++; sum += $2 }; END {count --; print "Number of processes =",count; print "Memory usage per process =",sum/1024/count, "MB"; print "Total memory usage =", sum/1024, "MB" ;};'

