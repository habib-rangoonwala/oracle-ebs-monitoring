#!/bin/ksh

###############################################################
#	Author: 	Habib Rangoonwala
#	Creation Date:	08-Feb-2010
#	Updation Date:	08-Feb-2010
###############################################################

if [ `uname` = 'Linux' ]; then
	echo $(cat /proc/cpuinfo|grep "processor"|wc -l)
fi
if [ `uname` = 'SunOS' ]; then
	echo $(psrinfo|wc -l)
fi
