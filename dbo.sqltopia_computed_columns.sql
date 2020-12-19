IF OBJECT_ID(N'dbo.sqltopia_computed_columns', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_computed_columns() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_computed_columns
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME,
        @new_column_name SYSNAME = NULL
)
RETURNS TABLE
AS
RETURN  WITH cteComputedColumns(schema_id, schema_name, table_id, table_name, column_id, column_name, is_persisted, computed_definition)
        AS (
                SELECT          sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                col.is_persisted,
                                CASE
                                        WHEN @new_column_name > N'' THEN REPLACE(col.definition COLLATE DATABASE_DEFAULT, QUOTENAME(@column_name), QUOTENAME(@new_column_name))
                                        ELSE col.definition COLLATE DATABASE_DEFAULT
                                END AS computed_definition
                FROM            sys.computed_columns AS col
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = col.object_id
                                        AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL)
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                        AND (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL)
                WHERE           (col.name COLLATE DATABASE_DEFAULT = @column_name OR @column_name IS NULL)
                                OR CHARINDEX(QUOTENAME(@column_name), col.definition COLLATE DATABASE_DEFAULT) >= 1
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteComputedColumns AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drop',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP COLUMN ', QUOTENAME(cte.column_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD ', QUOTENAME(cte.column_name), N' AS ', cte.computed_definition, CASE WHEN cte.is_persisted = 1 THEN N' PERSISTED;' ELSE N';' END)
                                        )
                        ) AS act(action_code, sql_text);
GO
