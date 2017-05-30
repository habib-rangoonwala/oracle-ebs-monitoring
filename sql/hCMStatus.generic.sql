REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM #	Updatid:	05-AUG-2010 [Method 2, WHERE CLAUSE to use session_id, instead of OS_PROCESS_ID
REM ###############################################################

SET SERVEROUTPUT ON SIZE 20000
REM ============================================================
REM ALTER SESSION ensures that FND_CONCURRENT call does not fail
REM ============================================================

ALTER SESSION SET CURRENT_SCHEMA=APPS;

DECLARE 
	hTarget 	NUMBER;
	hActive		NUMBER;
	hPMON		VARCHAR2(100);
	hStat		NUMBER;   
	hMessage1	VARCHAR2(100);
	hMessage2	VARCHAR2(100);
BEGIN

	-- Method 1
	APPS.FND_CONCURRENT.Get_Manager_Status(targetp => hTarget,activep => hActive,pmon_method => hPMON,callstat => hStat); 
	IF (hStat = 0 AND hActive > 0) THEN
		hMessage1:='RUNNING';
	ELSE
		hMessage1:='DOWN'; 
	END IF;
	
	-- Method 2
	SELECT	DECODE(COUNT(DISTINCT 1),1,'RUNNING','DOWN')
	INTO	hMessage2
	FROM	apps.fnd_concurrent_processes a,
			v$session	b
	WHERE	a.concurrent_queue_id=1
	AND		a.session_id=b.audsid;

	DBMS_OUTPUT.PUT_LINE(hMessage1||' '||hMessage2);
	
END;
/
