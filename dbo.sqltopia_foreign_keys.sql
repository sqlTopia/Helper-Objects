IF OBJECT_ID(N'dbo.sqltopia_foreign_keys', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_foreign_keys() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_foreign_keys
(
        @check_if_object_exist BIT = 1
)
/*
        sqltopia_foreign_keys v1.7.5 (2020-12-03)
        (C) 2009-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteForeignKeys(foreign_key_name, delete_action, update_action, parent_schema_id, parent_schema_name, parent_table_id, parent_table_name, parent_column_id, parent_column_name, parent_columnlist, child_schema_id, child_schema_name, child_table_id, child_table_name, child_column_id, child_column_name, child_columnlist, precheck)
        AS (
                SELECT          fk.name COLLATE DATABASE_DEFAULT AS foreign_key_name,
                                CASE
                                        WHEN fk.delete_referential_action = 1 THEN N'ON DELETE CASCADE'
                                        WHEN fk.delete_referential_action = 2 THEN N'ON DELETE SET NULL'
                                        WHEN fk.delete_referential_action = 3 THEN N'ON DELETE SET DEFAULT'
                                        ELSE N'ON DELETE NO ACTION'
                                END AS delete_action,
                                CASE
                                        WHEN fk.update_referential_action = 1 THEN N'ON UPDATE CASCADE'
                                        WHEN fk.update_referential_action = 2 THEN N'ON UPDATE SET NULL'
                                        WHEN fk.update_referential_action = 3 THEN N'ON UPDATE SET DEFAULT'
                                        ELSE N'ON UPDATE NO ACTION'
                                END AS update_action,
                                ps.schema_id AS parent_schema_id,
                                ps.name COLLATE DATABASE_DEFAULT AS parent_schema_name,
                                pt.object_id AS parent_table_id,
                                pt.name COLLATE DATABASE_DEFAULT AS parent_table_name,
                                pc.column_id AS parent_column_id,
                                pc.name COLLATE DATABASE_DEFAULT AS parent_column_name,
                                STUFF(p.columnlist.value(N'(text()[1])', N'NVARCHAR(MAX)'), 1, 2, N'') AS parent_columnlist,
                                cs.schema_id AS child_schema_id,
                                cs.name COLLATE DATABASE_DEFAULT AS child_schema_name,
                                ct.object_id AS child_table_id,
                                ct.name COLLATE DATABASE_DEFAULT AS child_table_name,
                                cc.column_id AS child_column_id,
                                cc.name COLLATE DATABASE_DEFAULT AS child_column_name,
                                STUFF(c.columnlist.value(N'(text()[1])', N'NVARCHAR(MAX)'), 1, 2, N'') AS child_columnlist,
                                CONCAT(N'EXISTS (SELECT * FROM sys.foreign_keys WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(fk.name COLLATE DATABASE_DEFAULT, N''''), N')') AS precheck
                FROM            sys.foreign_keys AS fk
                INNER JOIN      sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
                INNER JOIN      sys.columns AS pc ON pc.object_id = fkc.referenced_object_id
                                        AND pc.column_id = fkc.referenced_column_id
                INNER JOIN      sys.tables AS pt ON pt.object_id = pc.object_id
                INNER JOIN      sys.schemas AS ps ON ps.schema_id = pt.schema_id
                INNER JOIN      sys.columns AS cc ON cc.object_id = fkc.parent_object_id
                                        AND cc.column_id = fkc.parent_column_id
                INNER JOIN      sys.tables AS ct ON ct.object_id = cc.object_id
                INNER JOIN      sys.schemas AS cs ON cs.schema_id = pt.schema_id
                CROSS APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT))
                                        FROM            sys.foreign_key_columns AS fkc
                                        INNER JOIN      sys.columns AS col ON col.object_id = fkc.referenced_object_id
                                                                AND col.column_id = fkc.referenced_column_id
                                        WHERE           fkc.constraint_object_id = fk.object_id
                                                        AND fkc.referenced_object_id = fk.referenced_object_id
                                        ORDER BY        fkc.constraint_column_id
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS p(columnlist)
                CROSS APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT))
                                        FROM            sys.foreign_key_columns AS fkc
                                        INNER JOIN      sys.columns AS col ON col.object_id = fkc.parent_object_id
                                                                AND col.column_id = fkc.parent_column_id
                                        WHERE           fkc.constraint_object_id = fk.object_id
                                                        AND fkc.parent_object_id = fk.parent_object_id
                                        ORDER BY        fkc.constraint_column_id
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS c(columnlist)
        )
        SELECT          cte.foreign_key_name, 
                        cte.parent_schema_id, 
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