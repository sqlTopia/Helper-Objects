IF OBJECT_ID(N'dbo.sqltopia_default_constraints', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_default_constraints() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_default_constraints
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_default_constraints v2.0.0 (2021-01-01)
        (C) 2009-2021, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteDefaultConstraints(schema_id, schema_name, table_id, table_name, column_id, column_name, default_constraint_id, default_constraint_name, defafult_definition, precheck)
        AS (
                SELECT          sch.schema_id,
                                sch.schema_name,
                                tbl.table_id,
                                tbl.table_name,
                                col.column_id,
                                col.column_name,
                                dc.default_constraint_id,
                                dc.default_constraint_name,
                                dc.default_definition,
                                CONCAT(N'EXISTS (SELECT * FROM sys.default_constraints WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(dc.default_constraint_name, N''''), N')') AS precheck
                FROM            (
                                        SELECT  parent_object_id AS table_id,
                                                object_id AS default_constraint_id,
                                                name COLLATE DATABASE_DEFAULT AS default_constraint_name,
                                                parent_column_id AS column_id,
                                                definition COLLATE DATABASE_DEFAULT AS default_definition
                                        FROM    sys.default_constraints
                                ) AS dc
                INNER JOIN      (
                                        SELECT  schema_id,
                                                object_id AS table_id,
                                                name COLLATE DATABASE_DEFAULT AS table_name
                                        FROM    sys.tables
                                ) AS tbl ON tbl.table_id = dc.table_id
                INNER JOIN      (
                                        SELECT  schema_id,
                                                name COLLATE DATABASE_DEFAULT AS schema_name
                                        FROM    sys.schemas
                                ) AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      (
                                        SELECT  object_id AS table_id,
                                                column_id,
                                                name COLLATE DATABASE_DEFAULT AS column_name
                                        FROM    sys.columns
                                ) AS col ON col.table_id = dc.table_id
                                        AND col.column_id = dc.column_id 
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name, 
                        cte.column_id, 
                        cte.column_name,
                        cte.default_constraint_id, 
                        cte.default_constraint_name, 
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
