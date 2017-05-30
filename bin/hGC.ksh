#!/bin/ksh

###############################################################
#       Author:         Habib Rangoonwala
#       Creation Date:  03-May-2012
#       Updation Date:  03-May-2012
###############################################################

hFile='gcstat.txt'

hJavaVendor=`java -version 2>&1 |grep -i jrockit`

if [ "$hJavaVendor" = "" ]; then
        hJavaVendor="ORACLE"
else
        hJavaVendor="JROCKIT"
fi

if [ "$hJavaVendor"  = "ORACLE" ]; then
        hPID=`adopmnctl.sh status|grep oacore|cut -d "|" -f 3`
else
        hPID=`jps|grep Server|cut -d " " -f 1`
fi


while true
do

        for i in $hPID
        do

                hTimeStamp=`date`
                if [ "$hJavaVendor"  = "ORACLE" ]; then
                        hOutput=`jstat -gcutil $i 1s 1|tail -1`
                else
                        hOutput=`jstat -gc $i 1s 1|tail -1`
                fi
                echo $hOutput

                echo "$hTimeStamp $hOutput" >> "$hFile.$i"

        done

        sleep 60

done

exit 0
