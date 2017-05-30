#!/bin/sh
# Referenced Note 455154.1, modified it to my requirements
# Author: Habib Rangoonwala
# Updated: 14-MAY-2014

echo 
echo ----------------------------------------------- 
echo ----------- PRE-STOP EVENT SCRIPT -------------
echo -----------------------------------------------
echo

echo "$*"

. ~/.profile

timeStamp="N/A" 
instanceName="N/A" 
componentId="N/A" 
processType="N/A" 
processSet="N/A" 
processIndex="N/A" 
stderrPath="N/A"  # not available w/pre-start unless part of restart 
stdoutPath="N/A"  # not available w/pre-start unless part of restart 
reason="N/A" 
pid="N/A"         # only available with pre-stop, post-crash 
startTime="N/A"   # only available with pre-stop, post-crash 

while [ $# -gt 0 ]; do 
     case $1 in 
        -timeStamp)    timeStamp=$2; shift;; 
        -instanceName) instanceName=$2; shift;; 
        -componentId)  componentId=$2; shift;; 
        -processType)  processType=$2; shift;; 
        -processSet)   processSet=$2; shift;; 
        -processIndex) processIndex=$2; shift;; 
        -stderr)       stderrPath=$2; shift;; 
        -stdout)       stdoutPath=$2; shift;; 
        -reason)       reason=$2; shift;; 
        -pid)          pid=$2; shift;; 
        -startTime)    startTime=$2; shift;; 
        *) echo "Option Not Recognized: [$1]"; shift;; 
        esac 
        shift 
done 

echo timeStamp=$timeStamp 
echo instanceName=$instanceName 
echo componentId=$componentId 
echo processType=$processType 
echo processSet=$processSet 
echo processIndex=$processIndex 
echo stderr=$stderrPath 
echo stdout=$stdoutPath 
echo reason=$reason 
echo pid=$pid 
echo startTime=$startTime 

if [ "$reason" == "http_request" ]; then
	echo "Exiting as its user initiated request"
	kill -3 $pid

else
	hFilePrefix="$CONTEXT_NAME.`date +%Y.%m.%d.%H.%M.%S`.PID-$pid"
	hThreadDumpLoc="$APPLCSF/threaddump/"
	hFilename="${hThreadDumpLoc}${hFilePrefix}"


	echo "`date` - Running KILL -3"
	kill -3 $pid &> ${hFilename}_threaddump.log
	echo "`date` - Running JMAP..."
	jmap -dump:format=b,file=${hFilename}_heapdump.hprof $pid
	echo "`date` - Running TOP..."
	top -b -n 1 > ${hFilename}_top.log
	echo "`date` - Running PMAP.."
	pmap -x $pid  &> ${hFilename}_pmap.log
	echo "`date` - Running PSTACK..."
	pstack $pid &> ${hFilename}_pstack.log
	echo "`date` - Running LSOF..."
	lsof -p $pid &> ${hFilename}_lsof.log
	echo "`date` - Running JSTACK..."
	jstack $pid > ${hFilename}_jstack.log

	echo "`date` - Sending email..."
	mailx -s "$CONTEXT_NAME OACORE Pre-Stop ${hFilename}" no-reply@example.com < /dev/null

fi
echo "`date` - PRE-STOP Script Completed ... exiting."
kill -3 $pid
