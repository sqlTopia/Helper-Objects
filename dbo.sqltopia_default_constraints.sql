IF OBJECT_ID(N'dbo.sqltopia_default_constraints', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_default_constraints() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_default_constraints
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME,
        @new_column_name SYSNAME = NULL
)
RETURNS TABLE
AS
RETURN  WITH cteCheckConstraints(schema_id, schema_name, table_id, table_name, column_id, column_name, default_constraint_id, default_constraint_name, is_ms_shipped, default_definition)
        AS (
                SELECT          sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                dfc.object_id AS default_constraint_id,
                                dfc.name COLLATE DATABASE_DEFAULT AS default_constraint_name,
                                dfc.is_ms_shipped,
                                CASE
                                        WHEN col.name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN REPLACE(dfc.definition COLLATE DATABASE_DEFAULT, QUOTENAME(@column_name), QUOTENAME(@new_column_name))
                                        ELSE dfc.definition COLLATE DATABASE_DEFAULT
                                END AS default_definition
                FROM            sys.default_constraints AS dfc
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = dfc.parent_object_id
                                        AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL)
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                        AND (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL)
                INNER JOIN      sys.columns AS col ON col.object_id = dfc.parent_object_id
                                        AND col.column_id = dfc.parent_column_id
                                        AND (col.name COLLATE DATABASE_DEFAULT = @column_name OR @column_name IS NULL)
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        cte.default_constraint_id, 
                        cte.default_constraint_name,
                        cte.is_ms_shipped,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteCheckConstraints AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drdk',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.default_constraint_name), N';')
                                        ),
                                        (
                                                N'crdk',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.default_constraint_name), N' DEFAULT ', cte.default_definition, N' FOR ', QUOTENAME(cte.column_name), N';')
                                        )
                        ) AS act(action_code, sql_text);
GO
