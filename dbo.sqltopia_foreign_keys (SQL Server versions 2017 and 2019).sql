IF OBJECT_ID(N'dbo.sqltopia_foreign_keys', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_foreign_keys() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_foreign_keys
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME,
        @new_column_name SYSNAME = NULL
)
RETURNS TABLE
RETURN  WITH cteForeignKeys
        AS (
                SELECT          fk.object_id AS foreign_key_id,
                                fk.name COLLATE DATABASE_DEFAULT AS foreign_key_name,
                                ps.schema_id AS parent_schema_id,
                                ps.name COLLATE DATABASE_DEFAULT AS parent_schema_name,
                                pt.object_id AS parent_table_id,
                                pt.name COLLATE DATABASE_DEFAULT AS parent_table_name,
                                pcols.content AS parent_columns,
                                cs.schema_id AS child_schema_id,
                                cs.name COLLATE DATABASE_DEFAULT AS child_schema_name,
                                ct.object_id AS child_table_id,
                                ct.name COLLATE DATABASE_DEFAULT AS child_table_name,
                                ccols.content AS child_columns,
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
                                fk.is_disabled,
                                fk.is_ms_shipped,
                                fk.is_not_trusted
                FROM            sys.foreign_keys AS fk
                INNER JOIN      sys.tables AS pt ON pt.object_id = fk.referenced_object_id
                INNER JOIN      sys.schemas AS ps ON ps.schema_id = pt.schema_id
                INNER JOIN      sys.tables AS ct ON ct.object_id = fk.parent_object_id
                INNER JOIN      sys.schemas AS cs ON cs.schema_id = ct.schema_id
                CROSS APPLY     (
                                        SELECT          STRING_AGG(CASE WHEN pc.name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN QUOTENAME(@new_column_name) ELSE QUOTENAME(pc.name COLLATE DATABASE_DEFAULT) END, N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id)
                                        FROM            sys.foreign_key_columns AS fkc
                                        INNER JOIN      sys.columns AS pc ON pc.object_id = fkc.referenced_object_id
                                                                AND pc.column_id = fkc.referenced_column_id
                                        WHERE           fkc.constraint_object_id = fk.object_id
                                ) pcols(content)
                CROSS APPLY     (
                                        SELECT          STRING_AGG(CASE WHEN pc.name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN QUOTENAME(@new_column_name) ELSE QUOTENAME(pc.name COLLATE DATABASE_DEFAULT) END, N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id)
                                        FROM            sys.foreign_key_columns AS fkc
                                        INNER JOIN      sys.columns AS pc ON pc.object_id = fkc.parent_object_id
                                                                AND pc.column_id = fkc.parent_column_id
                                        WHERE           fkc.constraint_object_id = fk.object_id
                                ) ccols(content)
                WHERE           (
                                        ps.name COLLATE DATABASE_DEFAULT = @schema_name
                                        OR cs.name COLLATE DATABASE_DEFAULT = @schema_name
                                        OR @schema_name IS NULL
                                )
                                AND
                                (
                                        pt.name COLLATE DATABASE_DEFAULT = @table_name
                                        OR ct.name COLLATE DATABASE_DEFAULT = @table_name
                                        OR @table_name IS NULL
                                )
                                AND
                                (
                                        CHARINDEX(QUOTENAME(COALESCE(@new_column_name, @column_name)), pcols.content) >= 1
                                        OR CHARINDEX(QUOTENAME(COALESCE(@new_column_name, @column_name)), ccols.content) >= 1
                                        OR @column_name IS NULL AND @new_column_name IS NULL
                                )
        )
        SELECT          cte.foreign_key_id,
                        cte.foreign_key_name,
                        cte.is_not_trusted,
                        cte.parent_schema_id,
                        cte.parent_schema_name,
                        cte.parent_table_id,
                        cte.parent_table_name,
                        cte.child_schema_id,
                        cte.child_schema_name,
                        cte.child_table_id,
                        cte.child_table_name,
                        cte.is_disabled,
                        cte.is_ms_shipped,
                        cte.is_not_trusted,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteForeignKeys AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drfk',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name), N'.', QUOTENAME(cte.child_table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.foreign_key_name), N';')
                                        ),
                                        (
                                                N'crfk',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name), N'.', QUOTENAME(cte.child_table_name), N' WITH CHECK ADD CONSTRAINT ', QUOTENAME(cte.foreign_key_name), N' FOREIGN KEY (', cte.child_columns, N') REFERENCES ', QUOTENAME(cte.parent_schema_name), N'.', QUOTENAME(cte.parent_table_name), N' (', cte.parent_columns, N') ', cte.update_action, N' ', cte.delete_action, N';')
                                        ),
                                        (
                                                N'difk',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name), N'.', QUOTENAME(cte.child_table_name), N' NOCHECK CONSTRAINT ' + QUOTENAME(cte.foreign_key_name ), N';')
                                        ),
                                        (
                                                N'enfk',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.child_schema_name) + N'.' + QUOTENAME(cte.child_table_name) + N' WITH CHECK CHECK CONSTRAINT ' + QUOTENAME(cte.foreign_key_name), N';')
                                        )
                        ) AS act(action_code, sql_text);
GO
