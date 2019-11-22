/*
 * @autor: Felipe Donoso Batias, felipe@felipedonoso.cl felipe.donoso@oracle.com
 * @fecha: 2019-10-29
 */
 
 PROMPT 
 PROMPT +------------------------------------------------------------------------------------+
 PROMPT | Script para mostrar en modo texto informacion de AWR y filtrando ciertas secciones |
 PROMPT | @author: Felipe Donoso B. felipe@felipedonoso.cl felipe.donoso@oracle.com          |
 PROMPT |                                                                                    |
 PROMPT | Ejemplo de utilizacion del script:                                                 |
 PROMPT | Parametros:                                                                        |
 PROMPT | @xxxxxx.sql FECHA_INICIO_SNAP_AWR FECHA_FIN_SNAP_AWR SECCION_DE_REPORTE_A_FILTRAR  |
 PROMPT |                                                                                    |
 PROMPT | Formato:                                                                           |
 PROMPT | @xxxxxx.sql  yyyymmdd_hh24mi  yyyymmdd_hh24mi  "%seccion%"                         |
 PROMPT |                                                                                    |
 PROMPT | Ejemplos:                                                                          |
 PROMPT | @FDB_awr_resumen_filtrado 20191120_1000 20191122_1000 "Top Timed Foreground Events"|
 PROMPT | @FDB_awr_resumen_filtrado 20191028_1100 20191101_1500 "Database Summary"           |
 PROMPT | @FDB_awr_resumen_filtrado 20191028_1100 20191101_1500 "Cache Sizes"                |
 PROMPT | @FDB_awr_resumen_filtrado 20191028_1100 20191101_1500 "Time Model"                 |
 PROMPT | @FDB_awr_resumen_filtrado 20191028_1100 20191101_1500 "Time Model - % of DB time"  |
 PROMPT | @FDB_awr_resumen_filtrado 20191028_1100 20191101_1500 "Top Timed Foreground Eve%"  |
 PROMPT | @FDB_awr_resumen_filtrado 20191028_1100 20191101_1500 "SQL ordered by CPU%"        |
 PROMPT | @FDB_awr_resumen_filtrado 20191028_1100 20191101_1500 "SQL ordered by%"            |
 PROMPT +------------------------------------------------------------------------------------+

 
 -- Declaracion de Variables no eliminar nada de aqui por favor
SET VERIFY OFF FEEDBACK OFF TERMOUT OFF HEADING OFF
SET LINES 600

COLUMN f_ini NEW_VALUE fecha_ini
COLUMN f_fin NEW_VALUE fecha_fin
SELECT   NVL( trim('&&1') ,TO_CHAR(SYSDATE - 1, 'yyyymmdd_hh24mi') ) f_ini 
        ,NVL( trim('&&2') ,TO_CHAR(SYSDATE, 'yyyymmdd_hh24mi') )    f_fin
FROM dual
;

--ACCEPT fecha_ini_awr CHAR DEFAULT &fecha_ini PROMPT '* Ingresar fecha inicio Snap, formato [yyyymmdd_hh24mi] (default: &fecha_ini):  '
--ACCEPT fecha_fin_awr CHAR DEFAULT &fecha_fin PROMPT '* Ingresar fecha fin Snap, formato    [yyyymmdd_hh24mi] (default: &fecha_fin):  '

COLUMN snap_id_ini NEW_VALUE snap_ini
COLUMN snap_id_fin NEW_VALUE snap_fin
SELECT min(snap_id) snap_id_ini, max(snap_id) snap_id_fin
FROM dba_hist_snapshot
WHERE 
        (begin_interval_time >= TO_DATE('&fecha_ini','yyyymmdd_hh24mi') OR end_interval_time >= TO_DATE('&fecha_ini','yyyymmdd_hh24mi') )
    AND (begin_interval_time <= TO_DATE('&fecha_fin','yyyymmdd_hh24mi') OR end_interval_time <= TO_DATE('&fecha_fin','yyyymmdd_hh24mi') )
;

-- Query del reporte

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
) WHERE seccion like '&&3'
;

