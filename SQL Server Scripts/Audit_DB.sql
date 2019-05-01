--#Choose DB for add audit
--#All changes will be tracked to 'Audit' Table(will be added by this script)
--#source: https://github.com/doxakis/Generic-SQL-Audit-Trail

USE DB_NAME_
 
DECLARE @DatabaseName VARCHAR(255);
SELECT @DatabaseName = TABLE_CATALOG FROM information_schema.columns
 
PRINT 'Starting script...'
PRINT ''
PRINT 'Environnement:'
PRINT ' Server:'
PRINT '  ' + CAST(SERVERPROPERTY('ServerName') AS VARCHAR(255))
PRINT ' Edition:'
PRINT '  ' + CAST(SERVERPROPERTY('Edition') AS VARCHAR(255))
PRINT ' Database name:'
PRINT '  ' + @DatabaseName
PRINT ''
 
PRINT 'Starting: Removing all triggers starting with tr_audit_'
DECLARE @TriggerName VARCHAR(255);
DECLARE MY_CURSOR_FOR_TRIGGER CURSOR
    LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR
    -- Get list of trigger in current database
    SELECT
         sysobjects.name AS trigger_name
    FROM sysobjects
    WHERE
        sysobjects.type = 'TR' AND
        sysobjects.name LIKE 'tr_audit_%'
OPEN MY_CURSOR_FOR_TRIGGER
FETCH NEXT FROM MY_CURSOR_FOR_TRIGGER INTO @TriggerName
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @sql VARCHAR(250)
     
    -- Remove current trigger
    SET @sql = 'DROP TRIGGER ' + @TriggerName
    PRINT 'Removing trigger: ' + @TriggerName
    EXEC (@sql)
     
    FETCH NEXT FROM MY_CURSOR_FOR_TRIGGER INTO @TriggerName
END
CLOSE MY_CURSOR_FOR_TRIGGER
DEALLOCATE MY_CURSOR_FOR_TRIGGER
PRINT 'Finished: Removing all triggers starting with tr_audit_'
PRINT ''
 
PRINT 'Starting: Make sure Audit table exists'
IF NOT EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[dbo].[Audit]'))
BEGIN
    PRINT 'Adding Audit table in the database'
    CREATE TABLE Audit
       (Type CHAR(1), 
       TableName VARCHAR(128), 
       PK VARCHAR(1000), 
       FieldName VARCHAR(128), 
       OldValue VARCHAR(MAX), 
       NewValue VARCHAR(MAX), 
       UpdateDate datetime,
       UpdateBy VARCHAR(128))
END
GO
PRINT 'Finished: Make sure Audit table exists'
PRINT ''
 
DECLARE @sqlCreateTriggerTemplate VARCHAR(8000)
SET @sqlCreateTriggerTemplate = 'CREATE TRIGGER tr_audit_$$TableName$$
    ON [$$TableName$$] FOR INSERT, UPDATE, DELETE
    AS
    DECLARE @field INT,
           @maxfield INT,
           @char INT,
           @mask INT,
           @fieldname VARCHAR(128),
           @TableName VARCHAR(128),
           @PKCols VARCHAR(1000),
           @sql VARCHAR(8000), 
           @UpdateDate VARCHAR(21),
           @UserName VARCHAR(128),
           @Type CHAR(1),
           @PKSelect VARCHAR(1000)
    SET NOCOUNT ON
    --You will need to change @TableName to match the table to be audited
    SELECT @TableName = ''$$TableName$$''
    -- date and user
    SELECT @UserName = SYSTEM_USER,
           @UpdateDate = CONVERT(VARCHAR(8), GETDATE(), 112) 
                   + '' '' + CONVERT(VARCHAR(12), GETDATE(), 114)
    -- Action
    IF EXISTS (SELECT * FROM inserted)
           IF EXISTS (SELECT * FROM deleted)
                   SELECT @Type = ''U''
           ELSE
                   SELECT @Type = ''I''
    ELSE
           SELECT @Type = ''D''
    -- get list of columns
    SELECT * INTO #ins FROM inserted
    SELECT * INTO #del FROM deleted
    -- Get primary key columns for full outer join
    SELECT @PKCols = COALESCE(@PKCols + '' and'', '' on'') 
                   + '' i.'' + c.COLUMN_NAME + '' = d.'' + c.COLUMN_NAME
           FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
                  INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
           WHERE   pk.TABLE_NAME = @TableName
           AND     CONSTRAINT_TYPE = ''PRIMARY KEY''
           AND     c.TABLE_NAME = pk.TABLE_NAME
           AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
    -- Get primary key select for insert
    SELECT @PKSelect = COALESCE(@PKSelect+''+'','''') 
           + ''''''<'' + COLUMN_NAME 
           + ''=''''+convert(varchar(100),
    coalesce(i.'' + COLUMN_NAME +'',d.'' + COLUMN_NAME + ''))+''''>'''''' 
           FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
                   INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
           WHERE   pk.TABLE_NAME = @TableName
           AND     CONSTRAINT_TYPE = ''PRIMARY KEY''
           AND     c.TABLE_NAME = pk.TABLE_NAME
           AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
    IF @PKCols IS NULL
    BEGIN
           RAISERROR(''no PK on table %s'', 16, -1, @TableName)
           RETURN
    END
    SELECT @field = 0, 
           @maxfield = MAX(ORDINAL_POSITION) 
        FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName
    WHILE @field < @maxfield
    BEGIN
        SELECT @field = MIN(ORDINAL_POSITION) 
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = @TableName 
               AND ORDINAL_POSITION > @field
        IF @field IS NOT NULL
        BEGIN
            SELECT
                @field = MIN(ORDINAL_POSITION),
                @char = (column_id - 1) / 8 + 1,
                @mask = POWER(2, (column_id - 1) % 8),
                @fieldname = name
            FROM SYS.COLUMNS SC
            INNER JOIN INFORMATION_SCHEMA.COLUMNS ISC
            ON SC.name = ISC.COLUMN_NAME
            WHERE object_id = OBJECT_ID(@TableName)
            AND TABLE_NAME = @TableName
            AND ORDINAL_POSITION = @field
            GROUP BY column_id, name
            
           IF (SUBSTRING(COLUMNS_UPDATED(), @char, 1) & @mask) > 0
                                           OR @Type IN (''I'',''D'')
           BEGIN
               SELECT @sql = ''
                    INSERT Audit ( Type, 
                                   TableName, 
                                   PK, 
                                   FieldName, 
                                   OldValue, 
                                   NewValue, 
                                   UpdateDate,
                                   UpdateBy)
                    SELECT '''''' + @Type + '''''','''''' 
                           + @TableName + '''''','' + @PKSelect
                           + '','''''' + @fieldname + ''''''''
                           + '',convert(varchar(MAX),d.'' + @fieldname + '')''
                           + '',convert(varchar(MAX),i.'' + @fieldname + '')''
                           + '','''''' + @UpdateDate + ''''''''
                           + '','''''' + @UserName + ''''''''
                           + '' from #ins i full outer join #del d''
                           + @PKCols
                           + '' where i.'' + @fieldname + '' <> d.'' + @fieldname 
                           + '' or (i.'' + @fieldname + '' is null and  d.''
                                                    + @fieldname
                                                    + '' is not null)'' 
                           + '' or (i.'' + @fieldname + '' is not null and  d.'' 
                                                    + @fieldname
                                                    + '' is null)'' 
               EXEC (@sql)
            END
        END
    END'
 
PRINT 'Starting: Create audit trigger for all tables'
DECLARE @TableName VARCHAR(255);
DECLARE MY_CURSOR_FOR_TABLE CURSOR
    LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR
SELECT DISTINCT TABLE_NAME
FROM information_schema.columns
WHERE OBJECTPROPERTY(OBJECT_ID(TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME), 'IsView') = 0
OPEN MY_CURSOR_FOR_TABLE
FETCH NEXT FROM MY_CURSOR_FOR_TABLE INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
    If @TableName != 'Audit' -- Table used by audit trigger
        AND LEFT(@TableName, 7) <> 'aspnet_'
        AND LEFT(@TableName, 9) <> 'webpages_'
        -- Specify table to exclude here:
        -- Copy paste line bellow to specify table to exclude more table:
        --AND @TableName != 'VersionInfo' -- Table used by FluentMigrator
    BEGIN
        PRINT 'Adding trigger for table: ' + @TableName
        DECLARE @sql VARCHAR(8000)
        SET @sql = REPLACE(@sqlCreateTriggerTemplate, '$$TableName$$', @TableName)
        EXEC(@sql)
    END
    ELSE
    BEGIN
        PRINT 'Trigger not added for table: ' + @TableName
    END
    FETCH NEXT FROM MY_CURSOR_FOR_TABLE INTO @TableName
END
CLOSE MY_CURSOR_FOR_TABLE
DEALLOCATE MY_CURSOR_FOR_TABLE
PRINT 'Finished: Create audit trigger for all tables'
 
PRINT 'Starting: Create audit trigger on database for futures tables'
 
IF EXISTS(
  SELECT *
    FROM sys.triggers
   WHERE name = N'tr_database_audit'
     AND parent_class_desc = N'DATABASE'
)
    DROP TRIGGER tr_database_audit ON DATABASE
GO
 
CREATE TRIGGER tr_database_audit ON DATABASE
    FOR CREATE_TABLE
AS
    DECLARE @TableName SYSNAME
    SELECT @TableName = EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]','SYSNAME')
    DECLARE @sqlCreateTriggerTemplate VARCHAR(8000)
    SET @sqlCreateTriggerTemplate = 'CREATE TRIGGER tr_audit_$$TableName$$
        ON [$$TableName$$] FOR INSERT, UPDATE, DELETE
        AS
        DECLARE @field INT,
               @maxfield INT,
               @char INT,
               @mask INT,
               @fieldname VARCHAR(128),
               @TableName VARCHAR(128),
               @PKCols VARCHAR(1000),
               @sql VARCHAR(8000), 
               @UpdateDate VARCHAR(21),
               @UserName VARCHAR(128),
               @Type CHAR(1),
               @PKSelect VARCHAR(1000)
        SET NOCOUNT ON
        --You will need to change @TableName to match the table to be audited
        SELECT @TableName = ''$$TableName$$''
        -- date and user
        SELECT @UserName = SYSTEM_USER,
               @UpdateDate = CONVERT(VARCHAR(8), GETDATE(), 112) 
                       + '' '' + CONVERT(VARCHAR(12), GETDATE(), 114)
        -- Action
        IF EXISTS (SELECT * FROM inserted)
               IF EXISTS (SELECT * FROM deleted)
                       SELECT @Type = ''U''
               ELSE
                       SELECT @Type = ''I''
        ELSE
               SELECT @Type = ''D''
        -- get list of columns
        SELECT * INTO #ins FROM inserted
        SELECT * INTO #del FROM deleted
        -- Get primary key columns for full outer join
        SELECT @PKCols = COALESCE(@PKCols + '' and'', '' on'') 
                       + '' i.'' + c.COLUMN_NAME + '' = d.'' + c.COLUMN_NAME
               FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
                      INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
               WHERE   pk.TABLE_NAME = @TableName
               AND     CONSTRAINT_TYPE = ''PRIMARY KEY''
               AND     c.TABLE_NAME = pk.TABLE_NAME
               AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
        -- Get primary key select for insert
        SELECT @PKSelect = COALESCE(@PKSelect+''+'','''') 
               + ''''''<'' + COLUMN_NAME 
               + ''=''''+convert(varchar(100),
        coalesce(i.'' + COLUMN_NAME +'',d.'' + COLUMN_NAME + ''))+''''>'''''' 
               FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
                       INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
               WHERE   pk.TABLE_NAME = @TableName
               AND     CONSTRAINT_TYPE = ''PRIMARY KEY''
               AND     c.TABLE_NAME = pk.TABLE_NAME
               AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
        IF @PKCols IS NULL
        BEGIN
               RAISERROR(''no PK on table %s'', 16, -1, @TableName)
               RETURN
        END
        SELECT @field = 0, 
               @maxfield = MAX(ORDINAL_POSITION) 
            FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName
        WHILE @field < @maxfield
        BEGIN
            SELECT @field = MIN(ORDINAL_POSITION) 
                   FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = @TableName 
                   AND ORDINAL_POSITION > @field
            IF @field IS NOT NULL
            BEGIN
                SELECT
                    @field = MIN(ORDINAL_POSITION),
                    @char = (column_id - 1) / 8 + 1,
                    @mask = POWER(2, (column_id - 1) % 8),
                    @fieldname = name
                FROM SYS.COLUMNS SC
                INNER JOIN INFORMATION_SCHEMA.COLUMNS ISC
                ON SC.name = ISC.COLUMN_NAME
                WHERE object_id = OBJECT_ID(@TableName)
                AND TABLE_NAME = @TableName
                AND ORDINAL_POSITION = @field
                GROUP BY column_id, name
                
               IF (SUBSTRING(COLUMNS_UPDATED(), @char, 1) & @mask) > 0
                                               OR @Type IN (''I'',''D'')
               BEGIN
                   SELECT @sql = ''
                        INSERT Audit ( Type, 
                                       TableName, 
                                       PK, 
                                       FieldName, 
                                       OldValue, 
                                       NewValue, 
                                       UpdateDate,
                                       UpdateBy)
                        SELECT '''''' + @Type + '''''','''''' 
                               + @TableName + '''''','' + @PKSelect
                               + '','''''' + @fieldname + ''''''''
                               + '',convert(varchar(MAX),d.'' + @fieldname + '')''
                               + '',convert(varchar(MAX),i.'' + @fieldname + '')''
                               + '','''''' + @UpdateDate + ''''''''
                               + '','''''' + @UserName + ''''''''
                               + '' from #ins i full outer join #del d''
                               + @PKCols
                               + '' where i.'' + @fieldname + '' <> d.'' + @fieldname 
                               + '' or (i.'' + @fieldname + '' is null and  d.''
                                                        + @fieldname
                                                        + '' is not null)'' 
                               + '' or (i.'' + @fieldname + '' is not null and  d.'' 
                                                        + @fieldname
                                                        + '' is null)'' 
                   EXEC (@sql)
                END
            END
        END'
    DECLARE @sql VARCHAR(8000)
    SET @sql = REPLACE(@sqlCreateTriggerTemplate, '$$TableName$$', @TableName)
    EXEC(@sql)
GO
 
PRINT 'Finished: Create audit trigger on database for futures tables'
 
PRINT ''
PRINT 'Finished!'