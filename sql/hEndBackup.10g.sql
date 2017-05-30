REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM ###############################################################
ALTER DATABASE END BACKUP;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ARCHIVE LOG ALL
SELECT sequence# FROM v$log WHERE status='CURRENT';
ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
exit;
