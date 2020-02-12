
-- @author Graham Wood
-- DBTIME por sql_id de la ultima hora
SELECT sql_id
    , COUNT(*) dbtime_seg
    , ROUND(COUNT(*) * 100 / SUM(COUNT(*)) 
                                OVER(),2) pctload
FROM v$active_session_history
WHERE sample_time > SYSDATE - 1/24/60
AND session_type <> 'BACKGROUND'
GROUP BY sql_id
ORDER BY COUNT(*) desc ;