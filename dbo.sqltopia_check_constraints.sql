IF OBJECT_ID(N'dbo.sqltopia_check_constraints', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_check_constraints() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_check_constraints
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME,
        @new_column_name SYSNAME = NULL
)
RETURNS TABLE
RETURN  WITH cteCheckConstraints(schema_id, schema_name, table_id, table_name, column_id, column_name, check_constraint_id, check_constraint_name, is_disabled, is_ms_shipped, is_not_trusted, check_definition)
        AS (
                SELECT          sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                chc.object_id AS check_constraint_id,
                                chc.name COLLATE DATABASE_DEFAULT AS check_constraint_name,
                                chc.is_disabled,
                                chc.is_ms_shipped,
                                chc.is_not_trusted,
                                CASE
                                        WHEN col.name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN REPLACE(chc.definition COLLATE DATABASE_DEFAULT, QUOTENAME(@column_name), QUOTENAME(@new_column_name))
                                        ELSE chc.definition COLLATE DATABASE_DEFAULT
                                END AS check_definition
                FROM            sys.check_constraints AS chc
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = chc.parent_object_id
                                        AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL)
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                        AND (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL)
                INNER JOIN      sys.columns AS col ON col.object_id = tbl.object_id
                                        AND (col.name COLLATE DATABASE_DEFAULT = @column_name OR @column_name IS NULL)
                WHERE           col.column_id = chc.parent_column_id
                                OR CHARINDEX(QUOTENAME(col.name COLLATE DATABASE_DEFAULT), chc.definition COLLATE DATABASE_DEFAULT) >= 1
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        cte.check_constraint_id, 
                        cte.check_constraint_name, 
                        cte.is_disabled,
                        cte.is_ms_shipped,
                        cte.is_not_trusted,
                        CAST(chc.action_code AS NCHAR(4)) AS action_code,
                        chc.sql_text
        FROM            cteCheckConstraints AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drck',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N';')
                                        ),
                                        (
                                                N'crck',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' WITH CHECK ADD CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N' CHECK ', cte.check_definition, N';')
                                        ),
                                        (
                                                N'dick',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' NOCHECK CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N';')
                                        ),
                                        (
                                                N'enck',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' WITH CHECK CHECK CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N';')
                                        )
                        ) AS chc(action_code, sql_text);
GO
