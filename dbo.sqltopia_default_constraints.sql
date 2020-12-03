IF OBJECT_ID(N'dbo.sqltopia_default_constraints', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_default_constraints() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_default_constraints
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_default_constraints v1.7.5 (2020-12-03)
        (C) 2009-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteDefaultConstraints(default_constraint_name, schema_id, schema_name, table_id, table_name, column_id, column_name, definition, precheck)
        AS (
                SELECT          dc.name COLLATE DATABASE_DEFAULT AS default_constraint_name,
                                sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                dc.definition COLLATE DATABASE_DEFAULT AS definition,
                                CONCAT(N'EXISTS (SELECT * FROM sys.default_constraints WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(dc.name COLLATE DATABASE_DEFAULT, N''''), N')') AS precheck
                FROM            sys.default_constraints AS dc
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = dc.parent_object_id
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      sys.columns AS col ON col.object_id = dc.parent_object_id
                WHERE           col.column_id = dc.parent_column_id 
        )
        SELECT          cte.default_constraint_name, 
                        cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        CAST(act.query_action AS NVARCHAR(8)) AS query_action,
                        CASE
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'drop' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'create' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'disable' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'enable' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                ELSE act.query_text
                        END AS query_text
        FROM            cteDefaultConstraints AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drop',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.default_constraint_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.default_constraint_name), N' DEFAULT ', cte.definition, N' FOR ', QUOTENAME(cte.column_name), N';')
                                        )
                        ) AS act(query_action, query_text);
GO