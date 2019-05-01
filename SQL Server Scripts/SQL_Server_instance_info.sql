USE [master]
SELECT
    sess.host_name,
    dbs.name,
    sqltext.TEXT,
    req.session_id,
    req.status,
    req.command,
    req.cpu_time,
    req.reads,
    req.writes,
    req.total_elapsed_time,
    req.database_id
FROM sys.dm_exec_requests req
INNER JOIN sys.dm_exec_sessions sess on sess.session_id = req.session_id
INNER JOIN sys.databases dbs on dbs.database_id = req.database_id
CROSS APPLY sys.dm_exec_sql_text(sql_handle) sqltext