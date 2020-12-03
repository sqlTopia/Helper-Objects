IF OBJECT_ID(N'dbo.sqltopia_datatype_defaults', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_datatype_defaults() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_datatype_defaults
(
        @check_if_object_exist BIT = 0
)
/*
        sqltopia_datatype_defaults v1.7.2 (2020-11-15)
        (C) 2012-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteDefaults(schema_id, schema_name, table_id, table_name, column_id, column_name, default_name, definition, precheck)
        AS (
                SELECT          sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                obj.name COLLATE DATABASE_DEFAULT AS default_name,
                                sqm.definition COLLATE DATABASE_DEFAULT AS definition,
                                CONCAT(N'EXISTS(SELECT * FROM sys.columns AS cc INNER JOIN sys.tables AS tbl ON tbl.object_id = cc.object_id AND tbl.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(tbl.name COLLATE DATABASE_DEFAULT, N''''), N' INNER JOIN sys.schemas AS sch ON sch.schema_id = tbl.schema_id AND sch.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(sch.name COLLATE DATABASE_DEFAULT, N''''), N' WHERE cc.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(col.name COLLATE DATABASE_DEFAULT, N''''), N' AND cc.default_object_id <> 0)') AS precheck
                FROM            sys.columns AS col
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = col.object_id
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      sys.objects AS obj ON obj.object_id = col.default_object_id
                                        AND obj.type COLLATE DATABASE_DEFAULT = N'D'
                INNER JOIN      sys.sql_modules AS sqm ON sqm.object_id = col.default_object_id
                WHERE           col.default_object_id <> 0
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        CAST(act.query_action AS NVARCHAR(8)) AS query_action,
                        CASE
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'unbind' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'bind' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'drop' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'create' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                ELSE act.query_action
                        END AS query_text
        FROM            cteDefaults AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'unbind',
                                                CONCAT(N'EXEC sp_unbinddefault @objname = N''', REPLACE(QUOTENAME(cte.schema_name) + N'.' + QUOTENAME(cte.table_name) + N'.' + QUOTENAME(cte.column_name), N'''', N''''''), N''';')
                                        ),
                                        (
                                                N'bind',
                                                CONCAT(N'EXEC sp_binddefault @defname = N', QUOTENAME(cte.default_name, N''''), N', @objname = N''', REPLACE(QUOTENAME(cte.schema_name) + N'.' + QUOTENAME(cte.table_name) + N'.' + QUOTENAME(cte.column_name), N'''', N''''''), N''';')
                                        ),
                                        (
                                                N'drop',
                                                CONCAT(N'DROP DEFAULT ', QUOTENAME(cte.default_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(cte.definition, N';')
                                        )
                        ) AS act(query_action, query_text);
GO
