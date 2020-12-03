IF OBJECT_ID(N'dbo.sqltopia_computed_columns', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_computed_columns() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_computed_columns
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_computed_columns v1.7.5 (2020-12-03)
        (C) 2009-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteComputedColumns(schema_id, schema_name, table_id, table_name, column_id, column_name, computed_column_name, definition, is_persisted, precheck)
        AS (
                SELECT          sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                c.name COLLATE DATABASE_DEFAULT AS computed_column_name,
                                cc.definition COLLATE DATABASE_DEFAULT AS definition,
                                cc.is_persisted,
                                CONCAT(N'EXISTS (SELECT * FROM sys.computed_columns AS cc INNER JOIN sys.tables AS tbl ON tbl.object_id = cc.object_id AND tbl.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(tbl.name COLLATE DATABASE_DEFAULT, N''''), N' INNER JOIN sys.schemas AS sch ON sch.schema_id = tbl.schema_id AND sch.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(sch.name COLLATE DATABASE_DEFAULT, N''''), N' WHERE cc.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(c.name COLLATE DATABASE_DEFAULT, N''''), N')') AS precheck
                FROM            sys.schemas AS sch
                INNER JOIN      sys.tables AS tbl ON tbl.schema_id = sch.schema_id
                INNER JOIN      sys.columns AS col ON col.object_id = tbl.object_id
                INNER JOIN      sys.computed_columns AS cc ON cc.object_id = col.object_id
                                        AND CHARINDEX(QUOTENAME(col.name), cc.definition) >= 1
                INNER JOIN      sys.columns AS c ON c.object_id = cc.object_id
                                        AND c.column_id = cc.column_id
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        CAST(act.query_action AS NVARCHAR(8)) AS query_action,
                        CASE
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'drop' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'create' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                ELSE act.query_text
                        END AS query_text
        FROM            cteComputedColumns AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drop',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP COLUMN ', QUOTENAME(cte.computed_column_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD ', QUOTENAME(cte.computed_column_name), N' AS ', cte.definition, CASE WHEN cte.is_persisted = 1 THEN N' PERSISTED;' ELSE N';' END)
                                        )
                        ) AS act(query_action, query_text);
GO