REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM ###############################################################
SELECT
(SELECT instance_name FROM v$instance)||CHR(9)||
e.profile_option_name||CHR(9)||
DECODE(a.level_id,10001,'Site',10002,'Application',10003,'Resp',10004,'User')||CHR(9)||
DECODE(a.level_id,10001,'Site',10002,c.application_short_name,10003,b.responsibility_name,10004,d.user_name)||CHR(9)||
NVL(a.profile_option_value,'Is Null')||CHR(9)||
TO_CHAR(a.last_update_date,'dd-Mon-yyyy hh24:mi:ss')||CHR(9)||
f.user_name||'['||a.last_updated_by||']'
FROM
applsys.fnd_profile_option_values a,
applsys.fnd_responsibility_tl b,
applsys.fnd_application c,
applsys.fnd_user d,
applsys.fnd_profile_options e,
applsys.fnd_user f
WHERE
e.profile_option_id = a.profile_option_id
AND a.level_value = b.responsibility_id (+)
AND a.level_value = c.application_id (+)
AND a.level_value = d.user_id (+)
AND a.last_update_date > SYSDATE-7
AND a.last_updated_by = f.user_id
ORDER BY 
a.level_id,
a.last_update_date DESC;
