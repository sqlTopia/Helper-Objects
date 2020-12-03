IF OBJECT_ID(N'dbo.sqltopia_indexes', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_indexes() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_indexes
(
        @check_if_object_exist BIT = 0
)
/*
        sqltopia_indexes v1.7.2 (2020-11-15)
        (C) 2012-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  WITH cteIndexes(index_id, index_name, is_unique, is_primary_key, is_unique_constraint, type_desc, filter_definition, schema_id, schema_name, table_id, table_name, column_id, column_name, with_clause, on_clause, key_columns, include_columns, partition_columns, precheck)
        AS (
                SELECT          ind.index_id,
                                ind.name COLLATE DATABASE_DEFAULT AS index_name,
                                ind.is_unique,
                                ind.is_primary_key,
                                ind.is_unique_constraint,
                                ind.type_desc COLLATE DATABASE_DEFAULT AS type_desc,
                                ind.filter_definition COLLATE DATABASE_DEFAULT AS filter_definition,
                                sch.schema_id AS schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                col.column_id AS column_id,
                                col.name COLLATE DATABASE_DEFAULT AS column_name,
                                CONCAT(N'WITH (PAD_INDEX = ' + CASE WHEN ind.is_padded = 1 THEN N'ON' ELSE N'OFF' END, N', STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = ', CASE WHEN ind.ignore_dup_key = 1 THEN N'ON' ELSE N'OFF' END, N', ONLINE = OFF, ALLOW_ROW_LOCKS = ', CASE WHEN ind.allow_row_locks = 1 THEN N'ON' ELSE N'OFF' END, N', ALLOW_PAGE_LOCKS = ', CASE WHEN ind.allow_page_locks = 1 THEN N'ON' ELSE N'OFF' END, N', FILLFACTOR = ', CASE WHEN ind.fill_factor = 0 THEN N'100' ELSE CAST(ind.fill_factor AS NVARCHAR(3)) END, comp.content.value(N'(.)[1]', N'NVARCHAR(MAX)'), N')') AS with_clause,
                                CONCAT(N'ON ', QUOTENAME(ds.name COLLATE DATABASE_DEFAULT)) AS on_clause,
                                STUFF(k.content.value(N'(.)[1]', N'NVARCHAR(MAX)'), 1, 2, N'') AS key_columns,
                                STUFF(i.content.value(N'(.)[1]', N'NVARCHAR(MAX)'), 1, 2, N'') AS include_columns,
                                STUFF(p.content.value(N'(.)[1]', N'NVARCHAR(MAX)'), 1, 2, N'') AS partition_columns,
                                CONCAT(N'EXISTS(SELECT * FROM sys.indexes WHERE name COLLATE DATABASE_DEFAULT = N', QUOTENAME(ind.name COLLATE DATABASE_DEFAULT, N''''), N')') AS precheck
                FROM            sys.index_columns AS ic
                INNER JOIN      sys.indexes AS ind ON ind.object_id = ic.object_id
                                        AND ind.index_id = ic.index_id
                INNER JOIN      sys.columns AS col ON col.object_id = ic.object_id
                                        AND col.column_id = ic.column_id
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = ic.object_id
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                INNER JOIN      sys.data_spaces AS ds ON ds.data_space_id = ind.data_space_id
                OUTER APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT), CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END)
                                        FROM            sys.index_columns AS ic
                                        INNER JOIN      sys.columns AS col ON col.object_id = ic.object_id
                                                                AND col.column_id = ic.column_id
                                        WHERE           ic.object_id = ind.object_id
                                                        AND ic.index_id = ind.index_id
                                                        AND ic.key_ordinal >= 1
                                        ORDER BY        ic.key_ordinal
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS k(content)
                OUTER APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT))
                                        FROM            sys.index_columns AS ic
                                        INNER JOIN      sys.columns AS col ON col.object_id = ic.object_id
                                                                AND col.column_id = ic.column_id
                                        WHERE           ic.object_id = ind.object_id
                                                        AND ic.index_id = ind.index_id
                                                        AND ic.is_included_column = 1
                                        ORDER BY        ic.index_column_id
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS i(content)
                OUTER APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT))
                                        FROM            sys.index_columns AS ic
                                        INNER JOIN      sys.columns AS col ON col.object_id = ic.object_id
                                                                AND col.column_id = ic.column_id
                                        WHERE           ic.object_id = ind.object_id
                                                        AND ic.index_id = ind.index_id
                                                        AND ic.partition_ordinal >= 1
                                        ORDER BY        ic.partition_ordinal
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS p(content)
                OUTER APPLY     (
                                        SELECT          CONCAT(N', DATA_COMPRESSION = ', par.data_compression_desc COLLATE DATABASE_DEFAULT, N' ON PARTITIONS(', par.partition_number, N')')
                                        FROM            (
                                                                SELECT  par.data_compression_desc,
                                                                        par.partition_number,
                                                                        MAX(par.partition_number) OVER () AS partition_count
                                                                FROM    sys.partitions AS par
                                                                WHERE   par.object_id = ic.object_id
                                                                        AND par.index_id = ic.index_id
                                                        ) AS par
                                        WHERE           par.partition_count >= 2
                                        ORDER BY        par.partition_number
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS comp(content)
                WHERE           ind.type_desc COLLATE DATABASE_DEFAULT <> N'HEAP'
        )
        SELECT          cte.index_name, 
                        cte.type_desc,
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
        FROM            cteIndexes AS cte
        CROSS APPLY     (
                                SELECT  N'drop',
                                        CASE
                                                WHEN cte.is_primary_key = 1 OR cte.is_unique_constraint = 1 THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.index_name), N' WITH (ONLINE = OFF);')
                                                ELSE CONCAT(N'DROP INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' WITH (ONLINE = OFF);')
                                        END

                                UNION ALL

                                SELECT  N'create',
                                        CASE
                                                WHEN cte.is_primary_key = 1 THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.index_name), N' PRIMARY KEY ', CASE WHEN cte.type_desc = 'CLUSTERED' THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END)
                                                WHEN cte.is_unique_constraint = 1 THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.index_name), N' UNIQUE ', CASE WHEN cte.type_desc = 'CLUSTERED' THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END)
                                                ELSE CONCAT(N'CREATE ', CASE WHEN cte.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END, CASE WHEN cte.type_desc = 'CLUSTERED ' THEN N'CLUSTERED ' ELSE N'NONCLUSTERED ' END, N'INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name))
                                        END 
                                        + CONCAT(N' (', cte.key_columns, N')', CASE WHEN cte.include_columns IS NULL THEN N'' ELSE N' INCLUDE (' + cte.include_columns + N')' END, CASE WHEN cte.filter_definition IS NULL THEN N'' ELSE N' WHERE ' + cte.filter_definition END)
                                        + CONCAT(N' ', cte.with_clause)
                                        + CONCAT(N' ', CASE WHEN cte.partition_columns IS NULL THEN N'' ELSE N'(' + cte.partition_columns + N')' END, N';')

                                UNION ALL
                                
                                SELECT  N'disable',
                                        CONCAT(N'ALTER INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DISABLE;')

                                UNION ALL

                                SELECT  N'enable',
                                        CONCAT(N'ALTER INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' REBUILD PARTITION = ', CASE WHEN MAX(par.partition_number) OVER () = 1 THEN N'ALL' ELSE CAST(par.partition_number AS NVARCHAR(11)) END, N';')
                                FROM    sys.partitions AS par
                                WHERE   par.object_id = cte.table_id    
                                        AND par.index_id = cte.index_id
                        ) AS act(query_action, query_text);
GO
