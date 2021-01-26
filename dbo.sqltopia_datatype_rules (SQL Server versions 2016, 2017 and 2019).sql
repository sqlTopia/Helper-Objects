IF OBJECT_ID(N'dbo.sqltopia_datatype_rules', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_datatype_rules() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_datatype_rules
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME,
        @new_column_name SYSNAME
)
RETURNS TABLE
AS
RETURN  WITH cteRules(schema_id, schema_name, table_id, table_name, column_id, column_name, rule_id, rule_name, rule_definition)
        AS (
                SELECT          sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                def.object_id AS default_id,
                                def.name COLLATE DATABASE_DEFAULT AS default_name,
                                sqm.definition COLLATE DATABASE_DEFAULT AS default_definition
                FROM            sys.columns AS col
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = col.object_id
                                        AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL)
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                        AND (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL)
                INNER JOIN      sys.objects AS def ON def.object_id = col.default_object_id
                                        AND def.type COLLATE DATABASE_DEFAULT = 'R'
                INNER JOIN      sys.sql_modules AS sqm ON sqm.object_id = def.object_id
                WHERE           col.rule_object_id <> 0
                                AND (col.name COLLATE DATABASE_DEFAULT = @column_name OR @column_name IS NULL)
        )
        SELECT          cte.schema_id, 
                        cte.schema_name,
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        cte.rule_id,
                        cte.rule_name,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteRules AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'unru',
                                                CONCAT(N'EXEC sys.sp_unbindrule @objname = N''', REPLACE(QUOTENAME(cte.schema_name) + N'.' + QUOTENAME(cte.table_name) + N'.' + QUOTENAME(cte.column_name), N'''', N''''''), N''';')
                                        ),
                                        (
                                                N'biru',
                                                CONCAT(N'EXEC sys.sp_bindrule @defname = N', QUOTENAME(cte.rule_name, N''''), N', @objname = N''', REPLACE(QUOTENAME(cte.schema_name) + N'.' + QUOTENAME(cte.table_name) + N'.' + CASE WHEN cte.column_name = @column_name AND @new_column_name > N'' THEN QUOTENAME(@new_column_name) ELSE QUOTENAME(cte.column_name) END, N'''', N''''''), N''';')
                                        ),
                                        (
                                                N'drru',
                                                CONCAT(N'DROP RULE IF EXISTS ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.rule_name), N';')
                                        ),
                                        (
                                                N'crru',
                                                CONCAT(cte.rule_definition, N';')
                                        )
                        ) AS act(action_code, sql_text);
GO
