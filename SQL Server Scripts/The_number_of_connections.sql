SELECT
    DB_NAME(dbid) as DBName, 
    COUNT(dbid) as NumberOfConnections,
    loginame as LoginName
FROM
    sys.sysprocesses
WHERE
    dbid > 0
GROUP BY
    dbid, loginame

SELECT
    COUNT(dbid) as TotalConnections
FROM
    sys.sysprocesses
WHERE
    dbid > 0