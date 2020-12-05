IF OBJECT_ID(N'dbo.sqltopia_datatype_rules', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_datatype_rules() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_datatype_rules
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_datatype_rules v2.0.0 (2021-01-01)
        (C) 2009-2021, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteRules(schema_id, schema_name, table_id, table_name, column_id, column_name, rule_id, rule_name, rule_definition, precheck)
        AS (
                SELECT          sch.schema_id,
                                sch.schema_name,
                                tbl.table_id,
                                tbl.table_name,
                                col.column_id,
                                col.column_name,
                                r.rule_id,
                                r.rule_name,
                                r.rule_definition,
                                CONCAT(N'EXISTS (SELECT * FROM sys.columns AS cc INNER JOIN sys.tables AS tbl ON tbl.object_id = cc.object_id AND tbl.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(tbl.table_name, N''''), N' INNER JOIN sys.schemas AS sch ON sch.schema_id = tbl.schema_id AND sch.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(sch.schema_name, N''''), N' WHERE cc.name COLLATE DATABASE_DEFAULT = N', QUOTENAME(col.column_name, N''''), N' AND cc.rule_object_id <> 0)') AS precheck
                FROM            (
                                        SELECT  object_id AS table_id,
                                                column_id,
                                                name COLLATE DATABASE_DEFAULT AS column_name,
                                                rule_object_id AS rule_id
                                        FROM    sys.columns
                                ) AS col
                INNER JOIN      (
                                        SELECT  schema_id,
                                                object_id AS table_id,
                                                name COLLATE DATABASE_DEFAULT AS table_name
                                        FROM    sys.tables
                                ) AS tbl ON tbl.table_id = col.table_id
                INNER JOIN      (
                                        SELECT  schema_id,
                                                name COLLATE DATABASE_DEFAULT AS schema_name
                                        FROM    sys.schemas
                                ) AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      (
                                        SELECT          obj.object_id AS rule_id,
                                                        obj.name COLLATE DATABASE_DEFAULT AS rule_name,
                                                        sqm.definition COLLATE DATABASE_DEFAULT AS rule_definition
                                        FROM            sys.objects AS obj
                                        INNER JOIN      sys.sql_modules AS sqm ON sqm.object_id = obj.object_id
                                        WHERE           obj.type COLLATE DATABASE_DEFAULT = 'R'
                                                        AND obj.object_id <> 0
                                ) AS r ON r.rule_id = col.rule_id
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        cte.rule_id,
                        cte.rule_name,
                        CAST(act.query_action AS NVARCHAR(8)) AS query_action,
                        CASE
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'unbind' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'bind' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'drop' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'create' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                ELSE act.query_text
                        END AS query_text
        FROM            cteRules AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'unbind',
                                                CONCAT(N'EXEC sp_unbindrule @objname = N''', REPLACE(QUOTENAME(cte.schema_name) + N'.' + QUOTENAME(cte.table_name) + N'.' + QUOTENAME(cte.column_name), N'''', N''''''), N''';')
                                        ),
                                        (
                                                N'bind',
                                                CONCAT(N'EXEC sp_bindrule @rulename = N', QUOTENAME(cte.rule_name, N''''), N', @objname = N''', REPLACE(QUOTENAME(cte.schema_name) + N'.' + QUOTENAME(cte.table_name) + N'.' + QUOTENAME(cte.column_name), N'''', N''''''), N''';')
                                        ),
                                        (
                                                N'drop',
                                                CONCAT(N'DROP RULE ', QUOTENAME(cte.rule_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(cte.rule_definition, N';')
                                        )
                        ) AS act(query_action, query_text);
GO
