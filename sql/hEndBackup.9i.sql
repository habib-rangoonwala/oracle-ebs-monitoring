REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM ###############################################################

SET FEEDBACK off
SET PAGESIZE 0

SELECT name FROM v$database;
SELECT sequence# FROM v$log WHERE status='CURRENT';

SPOOL $hLogDirectory/end.sql
SELECT 'ALTER TABLESPACE ' ||tablespace_name ||' END BACKUP;' FROM dba_tablespaces WHERE tablespace_name NOT IN ('TEMP');
SPOOL OFF
@$hLogDirectory/end

ALTER SYSTEM SWITCH LOGFILE;
ARCHIVE LOG ALL
SELECT sequence# FROM v$log WHERE status='CURRENT';
ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
!rm $hLogDirectory/end.sql
EXIT;
