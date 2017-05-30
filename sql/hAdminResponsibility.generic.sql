REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM ###############################################################
SELECT
	(SELECT instance_name FROM v$instance)||CHR(9)||
	frt.responsibility_name||CHR(9)||
	fu.user_name||CHR(9)||
	TO_CHAR(furg.start_date,'DD-MON-RRRR HH24:MI:SS')||CHR(9)||
	TO_CHAR(furg.end_date,'DD-MON-RRRR HH24:MI:SS')
FROM
	apps.fnd_user_resp_groups_direct furg,
	apps.fnd_responsibility fr,
	apps.fnd_responsibility_tl frt,
	apps.fnd_user fu
WHERE	fu.user_id = furg.user_id
AND		furg.responsibility_id = fr.responsibility_id
AND		frt.responsibility_id = fr.responsibility_id
AND		furg.end_date IS NULL
AND		fu.end_date IS NULL
AND		frt.responsibility_name IN (&1)
ORDER	BY
		1
;
