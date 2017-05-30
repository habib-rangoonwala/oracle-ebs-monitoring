REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM ###############################################################
SELECT name FROM v$database;
SELECT sequence# FROM v$log WHERE status='CURRENT';
ALTER DATABASE BEGIN BACKUP;
exit;
