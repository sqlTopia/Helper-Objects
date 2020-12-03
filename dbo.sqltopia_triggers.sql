IF OBJECT_ID(N'dbo.sqltopia_triggers', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_triggers() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_triggers
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_triggers v1.7.5 (2020-12-03)
        (C) 2009-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteTriggers(trigger_name, schema_id, schema_name, table_id, table_name, definition, precheck)
        AS (
                SELECT          trg.name COLLATE DATABASE_DEFAULT AS trigger_name,
                                sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                sqm.definition COLLATE DATABASE_DEFAULT AS definition,
                                CONCAT(N'EXISTS (SELECT * FROM sys.triggers WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(trg.name COLLATE DATABASE_DEFAULT, N''''), N')') AS precheck
                FROM            sys.triggers AS trg
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = trg.parent_id
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      sys.sql_modules AS sqm ON sqm.object_id = trg.object_id
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
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
                                                CONCAT(cte.definition, N';')
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