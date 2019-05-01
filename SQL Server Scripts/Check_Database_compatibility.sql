USE [master]
select name, compatibility_level , version_name = 
CASE compatibility_level
    WHEN 65  THEN 'SQL Server 6.5'
    WHEN 70  THEN 'SQL Server 7.0'
    WHEN 80  THEN 'SQL Server 2000'
    WHEN 90  THEN 'SQL Server 2005'
    WHEN 100 THEN 'SQL Server 2008/R2'
    WHEN 110 THEN 'SQL Server 2012'
    WHEN 120 THEN 'SQL Server 2014'
    WHEN 130 THEN 'SQL Server 2016'
    WHEN 140 THEN 'SQL Server 2017'
    ELSE 'new unknown - ' + CONVERT(varchar(10),compatibility_level)
END
from sys.databases