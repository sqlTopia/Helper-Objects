IF OBJECT_ID(N'dbo.sqltopia_triggers', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_triggers() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_triggers
(
        @check_if_object_exist BIT = 1,
        @schema_name SYSNAME = NULL,
        @table_name SYSNAME = NULL,
        @trigger_name SYSNAME = NULL
)
/*
        sqltopia_triggers v2.0.0 (2021-01-01)
        (C) 2009-2021, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteTriggers(schema_id, schema_name, table_id, table_name, trigger_id, trigger_name, trigger_definition, precheck)
        AS (
                SELECT          sch.schema_id,
                                sch.schema_name,
                                tbl.table_id,
                                tbl.table_name,
                                trg.trigger_id,
                                trg.trigger_name,
                                sqm.trigger_definition,
                                CONCAT(N'EXISTS (SELECT * FROM sys.triggers WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(trg.trigger_name, N''''), N')') AS precheck
                FROM            (
                                        SELECT  parent_id AS table_id,
                                                object_id AS trigger_id,
                                                name COLLATE DATABASE_DEFAULT AS trigger_name
                                        FROM    sys.triggers
                                        WHERE   name COLLATE DATABASE_DEFAULT = @trigger_name AND @trigger_name IS NOT NULL
                                                OR @trigger_name IS NULL
                                ) AS trg
                INNER JOIN      (
                                        SELECT  schema_id,
                                                object_id AS table_id,
                                                name COLLATE DATABASE_DEFAULT AS table_name
                                        FROM    sys.tables
                                        WHERE   name COLLATE DATABASE_DEFAULT = @table_name AND @table_name IS NOT NULL
                                                OR @table_name IS NULL
                                ) AS tbl ON tbl.table_id = trg.table_id
                INNER JOIN      (
                                        SELECT  schema_id,
                                                name COLLATE DATABASE_DEFAULT AS schema_name
                                        FROM    sys.schemas
                                        WHERE   name COLLATE DATABASE_DEFAULT = @schema_name AND @schema_name IS NOT NULL
                                                OR @schema_name IS NULL
                                ) AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      (
                                        SELECT  object_id AS trigger_id,
                                                definition COLLATE DATABASE_DEFAULT AS trigger_definition
                                        FROM    sys.sql_modules
                                ) AS sqm ON sqm.trigger_id = trg.trigger_id
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name,
                        cte.trigger_id,
                        cte.trigger_name,
                        CAST(act.query_action AS NVARCHAR(8)) AS query_action,
                        CASE
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'drop' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'create' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'disable' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'enable' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                ELSE act.query_text
                        END AS query_text
        FROM            cteTriggers AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drop',
                                                CONCAT(N'DROP TRIGGER ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.trigger_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(cte.trigger_definition, N';')
                                        ),
                                        (
                                                N'disable',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DISABLE TRIGGER ', QUOTENAME(cte.trigger_name), N';')
                                        ),
                                        (
                                                N'enable',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ENABLE TRIGGER ', QUOTENAME(cte.trigger_name), N';')
                                        )
                        ) AS act(query_action, query_text);
GO
