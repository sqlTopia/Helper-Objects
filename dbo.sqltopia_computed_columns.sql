IF OBJECT_ID(N'dbo.sqltopia_computed_columns', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_computed_columns() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_computed_columns
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_computed_columns v2.0.0 (2021-01-01)
        (C) 2009-2021, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteComputedColumns(schema_id, schema_name, table_id, table_name, column_id, column_name, computed_column_name, computed_definition, is_persisted, precheck)
        AS (
                SELECT          sch.schema_id,
                                sch.schema_name,
                                tbl.table_id,
                                tbl.table_name,
                                col.column_id,
                                col.column_name,
                                cc.computed_column_name,
                                cc.computed_definition,
                                cc.is_persisted,
                                CONCAT(N'EXISTS (SELECT * FROM sys.computed_columns AS cc INNER JOIN sys.tables AS tbl ON tbl.object_id = cc.object_id AND tbl.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(tbl.table_name, N''''), N' INNER JOIN sys.schemas AS sch ON sch.schema_id = tbl.schema_id AND sch.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(sch.schema_name, N''''), N' WHERE cc.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(cc.computed_column_name, N''''), N')') AS precheck
                FROM            (
                                        SELECT  schema_id,
                                                name COLLATE DATABASE_DEFAULT AS schema_name
                                        FROM    sys.schemas
                                ) AS sch
                INNER JOIN      (
                                        SELECT  schema_id,
                                                object_id AS table_id,
                                                name COLLATE DATABASE_DEFAULT AS table_name
                                        FROM    sys.tables
                                ) AS tbl ON tbl.schema_id = sch.schema_id
                INNER JOIN      (
                                        SELECT  object_id AS table_id,
                                                column_id,
                                                name COLLATE DATABASE_DEFAULT AS column_name
                                        FROM    sys.columns
                                ) AS col ON col.table_id = tbl.table_id
                INNER JOIN      (
                                        SELECT  object_id AS table_id,
                                                name COLLATE DATABASE_DEFAULT AS computed_column_name,
                                                definition COLLATE DATABASE_DEFAULT AS computed_definition,
                                                is_persisted
                                        FROM    sys.computed_columns
                                ) AS cc ON cc.table_id = col.table_id
                                        AND CHARINDEX(QUOTENAME(col.column_name), cc.computed_definition) >= 1
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
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD ', QUOTENAME(cte.computed_column_name), N' AS ', cte.computed_definition, CASE WHEN cte.is_persisted = 1 THEN N' PERSISTED;' ELSE N';' END)
                                        )
                        ) AS act(query_action, query_text);
GO
