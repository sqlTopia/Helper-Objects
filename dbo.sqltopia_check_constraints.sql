IF OBJECT_ID(N'dbo.sqltopia_check_constraints', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_check_constraints() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_check_constraints
(
        @check_if_object_exist BIT = 0
)
/*
        sqltopia_check_constraints v1.7.2 (2020-11-15)
        (C) 2012-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteCheckConstraints(check_constraint_name, schema_id, schema_name, table_id, table_name, column_id, column_name, definition, precheck)
        AS (
                SELECT          cc.name COLLATE DATABASE_DEFAULT AS check_constraint_name,
                                sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                cc.definition COLLATE DATABASE_DEFAULT AS definition,
                                CONCAT(N'EXISTS(SELECT * FROM sys.check_constraints WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(cc.name COLLATE DATABASE_DEFAULT, N''''), N')') AS precheck
                FROM            sys.check_constraints AS cc
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = cc.parent_object_id
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      sys.columns AS col ON col.object_id = cc.parent_object_id
                WHERE           col.column_id = cc.parent_column_id 
                                OR CHARINDEX(QUOTENAME(col.name COLLATE DATABASE_DEFAULT), cc.definition COLLATE DATABASE_DEFAULT) >= 1
        )
        SELECT          cte.check_constraint_name, 
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
        FROM            cteCheckConstraints AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drop',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' WITH CHECK ADD CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N' CHECK ', cte.definition, N';')
                                        ),
                                        (
                                                N'disable',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' NOCHECK CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N';')
                                        ),
                                        (
                                                N'enable',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' WITH CHECK CHECK CONSTRAINT ', QUOTENAME(cte.check_constraint_name), N';')
                                        )
                        ) AS act(query_action, query_text);
GO
