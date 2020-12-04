IF OBJECT_ID(N'dbo.sqltopia_foreign_keys', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_foreign_keys() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_foreign_keys
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_foreign_keys v2.0.0 (2021-01-01)
        (C) 2009-2021, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteForeignKeys(parent_schema_id, parent_schema_name, parent_table_id, parent_table_name, parent_column_id, parent_column_name, child_schema_id, child_schema_name, child_table_id, child_table_name, child_column_id, child_column_name, foreign_key_id, foreign_key_name, delete_action, update_action, parent_columnlist, child_columnlist, precheck)
        AS (
                SELECT          pc.parent_schema_id,
                                pc.parent_schema_name,
                                pc.parent_table_id,
                                pc.parent_table_name,
                                pc.parent_column_id,
                                pc.parent_column_name,
                                cc.child_schema_id,
                                cc.child_schema_name,
                                cc.child_table_id,
                                cc.child_table_name,
                                cc.child_column_id,
                                cc.child_column_name,
                                fk.foreign_key_id,
                                fk.foreign_key_name,
                                fk.delete_action,
                                fk.update_action,
                                STUFF(p.columnlist.value(N'(text()[1])', N'NVARCHAR(MAX)'), 1, 2, N'') AS parent_columnlist,
                                STUFF(c.columnlist.value(N'(text()[1])', N'NVARCHAR(MAX)'), 1, 2, N'') AS child_columnlist,
                                CONCAT(N'EXISTS (SELECT * FROM sys.foreign_keys WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(fk.foreign_key_name, N''''), N')') AS precheck
                FROM            (
                                        SELECT  object_id AS foreign_key_id,
                                                name COLLATE DATABASE_DEFAULT AS foreign_key_name,
                                                CASE
                                                        WHEN delete_referential_action = 1 THEN N'ON DELETE CASCADE'
                                                        WHEN delete_referential_action = 2 THEN N'ON DELETE SET NULL'
                                                        WHEN delete_referential_action = 3 THEN N'ON DELETE SET DEFAULT'
                                                        ELSE N'ON DELETE NO ACTION'
                                                END AS delete_action,
                                                CASE
                                                        WHEN update_referential_action = 1 THEN N'ON UPDATE CASCADE'
                                                        WHEN update_referential_action = 2 THEN N'ON UPDATE SET NULL'
                                                        WHEN update_referential_action = 3 THEN N'ON UPDATE SET DEFAULT'
                                                        ELSE N'ON UPDATE NO ACTION'
                                                END AS update_action
                                        FROM    sys.foreign_keys
                                ) AS fk
                INNER JOIN      (
                                        SELECT  constraint_object_id AS foreign_key_id,
                                                referenced_object_id AS parent_table_id,
                                                referenced_column_id AS parent_column_id,
                                                parent_object_id AS child_table_id,
                                                parent_column_id AS child_column_id
                                        FROM    sys.foreign_key_columns
                                ) AS fkc ON fkc.foreign_key_id = fk.foreign_key_id
                INNER JOIN      (
                                        SELECT          sch.schema_id AS parent_schema_id,
                                                        sch.name COLLATE DATABASE_DEFAULT AS parent_schema_name,
                                                        tbl.object_id AS parent_table_id,
                                                        tbl.name COLLATE DATABASE_DEFAULT AS parent_table_name,
                                                        col.column_id AS parent_column_id,
                                                        col.name COLLATE DATABASE_DEFAULT AS parent_column_name
                                        FROM            sys.columns AS col
                                        INNER JOIN      sys.tables AS tbl ON tbl.object_id = col.object_id
                                        INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                ) AS pc ON pc.parent_table_id = fkc.parent_table_id
                                        AND pc.parent_column_id = fkc.parent_column_id
                INNER JOIN      (
                                        SELECT          sch.schema_id AS child_schema_id,
                                                        sch.name COLLATE DATABASE_DEFAULT AS child_schema_name,
                                                        tbl.object_id AS child_table_id,
                                                        tbl.name COLLATE DATABASE_DEFAULT AS child_table_name,
                                                        col.column_id AS child_column_id,
                                                        col.name COLLATE DATABASE_DEFAULT AS child_column_name
                                        FROM            sys.columns AS col
                                        INNER JOIN      sys.tables AS tbl ON tbl.object_id = col.object_id
                                        INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                ) AS cc ON cc.child_table_id = fkc.child_table_id
                                        AND cc.child_column_id = fkc.child_column_id
                CROSS APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT))
                                        FROM            sys.foreign_key_columns AS pfk
                                        INNER JOIN      sys.columns AS col ON col.object_id = pfk.referenced_object_id
                                                                AND col.column_id = pfk.referenced_column_id
                                        WHERE           pfk.constraint_object_id = fkc.foreign_key_id
                                                        AND pfk.referenced_object_id = fkc.parent_table_id
                                        ORDER BY        pfk.constraint_column_id
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS p(columnlist)
                CROSS APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT))
                                        FROM            sys.foreign_key_columns AS cfk
                                        INNER JOIN      sys.columns AS col ON col.object_id = cfk.parent_object_id
                                                                AND col.column_id = cfk.parent_column_id
                                        WHERE           cfk.constraint_object_id = fkc.foreign_key_id
                                                        AND cfk.parent_object_id = fkc.child_table_id
                                        ORDER BY        cfk.constraint_column_id
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS c(columnlist)
        )
        SELECT          cte.parent_schema_id, 
                        cte.parent_schema_name, 
                        cte.parent_table_id, 
                        cte.parent_table_name, 
                        cte.parent_column_id, 
                        cte.parent_column_name, 
                        cte.child_schema_id, 
                        cte.child_schema_name, 
                        cte.child_table_id, 
                        cte.child_table_name, 
                        cte.child_column_id, 
                        cte.child_column_name,
                        cte.foreign_key_id, 
                        cte.foreign_key_name, 
                        CAST(act.query_action AS NVARCHAR(8)) AS query_action,
                        CASE
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'drop' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'create' THEN CONCAT(N'IF NOT ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'disable' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                WHEN @check_if_object_exist = 1 AND act.query_action = N'enable' THEN CONCAT(N'IF ', cte.precheck, N' ', act.query_text)
                                ELSE act.query_text
                        END AS query_text
        FROM            cteForeignKeys AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drop',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name), N'.', QUOTENAME(cte.child_table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.foreign_key_name), N';')
                                        ),
                                        (
                                                N'create',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name), N'.', QUOTENAME(cte.child_table_name), N' WITH CHECK ADD CONSTRAINT ', QUOTENAME(cte.foreign_key_name), N' FOREIGN KEY (', cte.child_columnlist, N') REFERENCES ', QUOTENAME(cte.parent_schema_name), N'.', QUOTENAME(cte.parent_table_name), N' (', cte.parent_columnlist, N') ', cte.update_action, N' ', cte.delete_action, N';')
                                        ),
                                        (
                                                N'disable',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name), N'.', QUOTENAME(cte.child_table_name), N' NOCHECK CONSTRAINT ' + QUOTENAME(cte.foreign_key_name ), N';')
                                        ),
                                        (
                                                N'enable',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name) + N'.' + QUOTENAME(cte.child_table_name) + N' WITH CHECK CHECK CONSTRAINT ' + QUOTENAME(cte.foreign_key_name), N';')
                                        )
                        ) AS act(query_action, query_text);
GO
