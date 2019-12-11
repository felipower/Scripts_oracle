/*
 * @autor: Felipe Donoso Batias, felipe@felipedonoso.cl felipe.donoso@oracle.com
 * @fecha: 2019-10-29
 * 
 * Some additional examples:
 * @FDB_Oracle_AWR_summary_filtered "Time Model - % of D%" 20191028_1100 20191101_1500 
 * @FDB_Oracle_AWR_summary_filtered "Top Timed Foregro%" 20191028_1100 20191101_1500  
 * @FDB_Oracle_AWR_summary_filtered "SQL ordered by CPU%" 20191126_1100 20191127_1100
 * @FDB_Oracle_AWR_summary_filtered "SQL ordered by%" 20191126_1100 20191127_1100      
 * 
 */
 
 PROMPT 
 PROMPT +------------------------------------------------------------------------------------+
 PROMPT | Script for show some sections for AWR report with certain filters                  |
 PROMPT | @author: Felipe Donoso B. felipe@felipedonoso.cl felipe.donoso@oracle.com          |
 PROMPT |                                                                                    |
 PROMPT | Examples and parameters:                                                           |
 PROMPT | @xxxxxx.sql SECTIONS_NAME_TO_FILTER DATE_BEGIN_AWR DATE_END_AWR                    |
 PROMPT |                                                                                    |
 PROMPT | Format:                                                                            |
 PROMPT | @xxxxxx.sql  "%seccion%" yyyymmdd_hh24mi  yyyymmdd_hh24mi                          |
 PROMPT |                                                                                    |
 PROMPT | Example :                                                                          |
 PROMPT | @FDB_Oracle_AWR_summary_filtered "Top Timed Foregroun%" 20191120_1000 20191122_1000|
 PROMPT | @FDB_Oracle_AWR_summary_filtered "Database Summary" 20191120_1000 20191122_1000    |
 PROMPT | @FDB_Oracle_AWR_summary_filtered "Cache Sizes" 20191028_1100 20191101_1500         |
 PROMPT | @FDB_Oracle_AWR_summary_filtered "Time Model%" 20191028_1100 20191101_1500         |
 PROMPT +------------------------------------------------------------------------------------+

 
 -- Variables declaration, pls don't delete anything here, pls!!
SET VERIFY OFF FEEDBACK OFF TERMOUT OFF HEADING OFF
SET LINES 600

COLUMN f_ini NEW_VALUE fecha_ini
COLUMN f_fin NEW_VALUE fecha_fin
SELECT   NVL( trim('&&2') ,TO_CHAR(SYSDATE - 1, 'yyyymmdd_hh24mi') ) f_ini 
        ,NVL( trim('&&3') ,TO_CHAR(SYSDATE, 'yyyymmdd_hh24mi') )    f_fin
FROM dual
;

--ACCEPT fecha_ini_awr CHAR DEFAULT &fecha_ini PROMPT '* Ingresar fecha inicio Snap, formato [yyyymmdd_hh24mi] (default: &fecha_ini):  '
--ACCEPT fecha_fin_awr CHAR DEFAULT &fecha_fin PROMPT '* Ingresar fecha fin Snap, formato    [yyyymmdd_hh24mi] (default: &fecha_fin):  '

SET TERMOUT ON
PROMPT .
PROMPT * Este script utiliza DIAGNOSTICK PACK.
PROMPT * Si NO posee licencia porfavor cancele la ejecucion de este script.
PROMPT * De lo contrario presione enter para continuar.
ACCEPT continuar CHAR PROMPT '' HIDE
SET TERMOUT OFF

COLUMN snap_id_ini NEW_VALUE snap_ini
COLUMN snap_id_fin NEW_VALUE snap_fin
SELECT min(snap_id) snap_id_ini, max(snap_id) snap_id_fin
FROM dba_hist_snapshot
WHERE 
        (begin_interval_time >= TO_DATE('&fecha_ini','yyyymmdd_hh24mi') OR end_interval_time >= TO_DATE('&fecha_ini','yyyymmdd_hh24mi') )
    AND (begin_interval_time <= TO_DATE('&fecha_fin','yyyymmdd_hh24mi') OR end_interval_time <= TO_DATE('&fecha_fin','yyyymmdd_hh24mi') )
;

-- Query for Report AWR Text
SET TERMOUT ON
COL salida format a400
SELECT salida FROM (
    SELECT
         LAST_VALUE(seccion IGNORE NULLS) OVER (ORDER BY linea) seccion
        ,salida
    FROM(
        SELECT  ROWNUM linea
            ,CASE
                WHEN ROWNUM = 1 THEN TRIM(output)
                WHEN TRIM(output) = 'Database Summary' THEN TRIM(output)
                WHEN TRIM(output) = 'Cache Sizes' THEN TRIM(output)
                WHEN output like ('%DB/Inst%') THEN TRIM(REGEXP_REPLACE(output,' *DB/Inst.*$'))
                ELSE NULL
             END seccion
            ,output salida
                    FROM TABLE(
                            DBMS_WORKLOAD_REPOSITORY.AWR_GLOBAL_REPORT_TEXT(l_dbid=>(SELECT dbid FROM v$database),l_inst_num=>'',l_bid=>&snap_ini,l_eid=>&snap_fin,l_options=>1+4+8)
                    )
         ORDER BY 1
    ) 
) WHERE seccion like '&&1'
;

