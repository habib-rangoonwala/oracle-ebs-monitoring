REM ###############################################################
REM #	Author: 	Habib Rangoonwala
REM #	Created:	16-Mar-2007
REM #	Updated:	05-FEB-2010
REM ###############################################################
SELECT ts_size_mb||CHR(9)||
ROUND((undo_block_per_sec*dbblksize/1024),2)||CHR(9)||
ROUND((undo_block_per_sec*mxqrylen*dbblksize)/1024/1024,2)||CHR(9)||
mxqrylen||CHR(9)||
DBMS_UNDO_ADV.RBU_MIGRATION||CHR(9)||
ROUND((trn_max_used_blk*dbblksize)/1024/1024,2)||CHR(9)||
ROUND((trn_total_used_blk*dbblksize)/1024/1024,2)||CHR(9)||
trn_count||CHR(9)||
undo_retention||CHR(9)||
tuned_undoretention||CHR(9)||
min_tuned_undoretention
FROM
(
SELECT (SUM(undoblks))/ SUM ((end_time - begin_time) * 24*60*60) undo_block_per_sec, MAX(maxquerylen) mxqrylen, MIN(tuned_undoretention) min_tuned_undoretention FROM v$undostat
),
(
SELECT NVL(SUM(used_ublk),0) trn_total_used_blk ,NVL(MAX(used_ublk),0) trn_max_used_blk,COUNT(*) trn_count FROM v$transaction
),
(
SELECT value dbblksize from v$parameter where name='db_block_size'
),
(
SELECT ROUND(SUM(bytes)/1024/1024) ts_size_mb FROM dba_data_files WHERE tablespace_name = (SELECT UPPER(value) FROM v$parameter WHERE name='undo_tablespace')
),
(
SELECT tuned_undoretention FROM ( SELECT * FROM v$undostat ORDER BY end_time DESC) WHERE ROWNUM < 2
),
(
SELECT value undo_retention FROM v$parameter WHERE name='undo_retention'
);

