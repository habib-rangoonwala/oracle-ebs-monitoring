REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM ###############################################################
SET FEEDBACK off
SET PAGESIZE 0

SELECT name FROM v$database;
SELECT sequence# FROM v$log WHERE status='CURRENT';

SPOOL $hLogDirectory/begin.sql
SELECT 'ALTER TABLESPACE ' ||tablespace_name ||' BEGIN BACKUP;' FROM dba_tablespaces WHERE tablespace_name NOT IN ('TEMP');
SPOOL OFF
@$hLogDirectory/begin
!rm $hLogDirectory/begin.sql
EXIT;
