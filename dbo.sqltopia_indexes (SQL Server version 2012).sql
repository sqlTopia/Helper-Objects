IF OBJECT_ID(N'dbo.sqltopia_indexes', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_indexes() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_indexes
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME,
        @new_column_name SYSNAME = NULL
)
RETURNS TABLE
RETURN  WITH cteIndexes
        AS (
                SELECT          sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                ind.index_id,
                                ind.name COLLATE DATABASE_DEFAULT AS index_name,
                                ind.type AS index_type_major,
                                COALESCE(xix.xml_index_type, CAST(six.spatial_index_type AS TINYINT)) AS index_type_minor,
                                0 AS is_memory_optimized,
                                CASE
                                        WHEN dsp.name IS NULL THEN N''
                                        WHEN p.content IS NULL THEN CONCAT(N' ON ', QUOTENAME(dsp.name COLLATE DATABASE_DEFAULT))
                                        ELSE CONCAT(N' ON ', QUOTENAME(dsp.name COLLATE DATABASE_DEFAULT), N'(', STUFF(CAST(p.content AS NVARCHAR(MAX)), 1, 2, N''), N')')
                                END AS data_space_definition,
                                dsp.type AS data_space_type,
                                STUFF(CAST(c.content AS NVARCHAR(MAX)), 1, 2, N'') AS data_compression,
                                CASE
                                        WHEN k.content IS NULL THEN N''
                                        ELSE STUFF(CAST(k.content AS NVARCHAR(MAX)), 1, 2, N'')
                                END AS key_columns,
                                CASE
                                        WHEN i.content IS NULL THEN N''
                                        ELSE STUFF(CAST(i.content AS NVARCHAR(MAX)), 1, 2, N'')
                                END AS include_columns,
                                STUFF(CAST(o.content AS NVARCHAR(MAX)), 1, 2, N'') AS other_columns,
                                N'' AS bucket_count,
                                ind.is_primary_key,
                                ind.is_unique_constraint,
                                ind.is_unique,
                                N'' AS compression_delay,
                                CASE
                                        WHEN ind.filter_definition IS NULL THEN N''
                                        ELSE CONCAT(N' WHERE ', ind.filter_definition COLLATE DATABASE_DEFAULT)
                                END AS filter_definition,
                                xix.secondary_type_desc COLLATE DATABASE_DEFAULT AS xml_type_desc,
                                yix.name COLLATE DATABASE_DEFAULT AS primary_xml_index_name,
                                six.tessellation_scheme COLLATE DATABASE_DEFAULT AS tessellation_scheme,
                                N'ONLINE = OFF' AS online,
                                N'DROP_EXISTING = OFF' AS drop_existing,
                                CASE
                                        WHEN ind.is_padded = 1 THEN N'PAD_INDEX = ON'
                                        ELSE N'PAD_INDEX = OFF'
                                END AS pad_index,
                                CASE
                                        WHEN sta.no_recompute = 1 THEN N'STATISTICS_NORECOMPUTE = ON'
                                        ELSE N'STATISTICS_NORECOMPUTE = OFF'
                                END AS statistics_norecompute,
                                N'SORT_IN_TEMPDB = ON' AS sort_in_tempdb,
                                CASE
                                        WHEN ind.ignore_dup_key = 1 THEN N'IGNORE_DUP_KEY = ON'
                                        ELSE N'IGNORE_DUP_KEY = OFF'
                                END AS ignore_dup_key,
                                CASE
                                        WHEN ind.allow_row_locks = 1 THEN N'ALLOW_ROW_LOCKS = ON'
                                        ELSE N'ALLOW_ROW_LOCKS = OFF'
                                END AS allow_row_locks,
                                CASE 
                                        WHEN ind.allow_page_locks = 1 THEN N'ALLOW_PAGE_LOCKS = ON'
                                        ELSE N'ALLOW_PAGE_LOCKS = OFF'
                                END AS allow_page_locks,
                                CONCAT(N'FILLFACTOR = ', COALESCE(cfg.fill_factor, 100)) AS fill_factor,
                                pfs.page_count,
                                CASE
                                        WHEN six.spatial_index_type = 1 THEN CONCAT(N'BOUNDING_BOX = (', sit.bounding_box_xmin, N', ', sit.bounding_box_ymin, N', ', sit.bounding_box_xmax, N', ', sit.bounding_box_ymax, N')')
                                        ELSE N''
                                END AS bounding_box,
                                CONCAT(N'GRIDS = (LEVEL_1 = ', sit.level_1_grid_desc COLLATE DATABASE_DEFAULT, N', LEVEL_2 = ', sit.level_2_grid_desc COLLATE DATABASE_DEFAULT, N', LEVEL_3 = ', sit.level_3_grid_desc COLLATE DATABASE_DEFAULT, N', LEVEL_4 = ', sit.level_4_grid_desc COLLATE DATABASE_DEFAULT, N')') AS grids,
                                CONCAT(N', CELLS_PER_OBJECT = ', sit.cells_per_object) AS cells_per_object,
                                ind.is_disabled
                FROM            sys.indexes AS ind
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = ind.object_id
                                        AND tbl.type = 'U'
                                        AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL)
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                        AND (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL)
                CROSS APPLY     (
                                        SELECT  SUM(ps.used_page_count) AS page_count
                                        FROM    sys.dm_db_partition_stats AS ps
                                        WHERE   ps.object_id = ind.object_id
                                                AND ps.index_id = ind.index_id
                                ) AS pfs(page_count)
                LEFT JOIN       sys.data_spaces AS dsp ON dsp.data_space_id = ind.data_space_id
                LEFT JOIN       sys.xml_indexes AS xix ON xix.object_id = ind.object_id
                                        AND xix.index_id = ind.index_id
                LEFT JOIN       sys.xml_indexes AS yix ON yix.object_id = xix.object_id
                                        AND yix.index_id = xix.using_xml_index_id
                LEFT JOIN       sys.spatial_indexes AS six ON six.object_id = ind.object_id
                                        AND six.index_id = ind.index_id
                LEFT JOIN       sys.stats AS sta ON sta.object_id = ind.object_id
                                        AND sta.stats_id = ind.index_id
                LEFT JOIN       sys.spatial_index_tessellations AS sit ON sit.object_id = ind.object_id
                                        AND sit.index_id = ind.index_id
                OUTER APPLY     (
                                        SELECT  CASE
                                                        WHEN ind.fill_factor = 0 AND CONVERT(TINYINT, value) = 0 THEN CAST(100 AS TINYINT)
                                                        WHEN ind.fill_factor = 0 THEN CONVERT(TINYINT, value)
                                                        ELSE ind.fill_factor
                                                END AS fill_factor
                                        FROM    sys.configurations
                                        WHERE   configuration_id = 109
                                ) AS cfg(fill_factor)
                OUTER APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name), CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END)
                                        FROM            sys.index_columns AS ic
                                        INNER JOIN      (
                                                                SELECT  object_id,
                                                                        column_id,
                                                                        CASE
                                                                                WHEN name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN @new_column_name
                                                                                ELSE name COLLATE DATABASE_DEFAULT
                                                                        END AS name
                                                                FROM    sys.columns
                                                        ) AS col ON col.object_id = ic.object_id
                                                                AND col.column_id = ic.column_id
                                        WHERE           ic.object_id = ind.object_id
                                                        AND ic.index_id = ind.index_id
                                                        AND ic.key_ordinal >= 1
                                        ORDER BY        ic.key_ordinal
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS k(content)
                OUTER APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name))
                                        FROM            sys.index_columns AS ic
                                        INNER JOIN      (
                                                                SELECT  object_id,
                                                                        column_id,
                                                                        CASE
                                                                                WHEN name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN @new_column_name
                                                                                ELSE name COLLATE DATABASE_DEFAULT
                                                                        END AS name
                                                                FROM    sys.columns
                                                        ) AS col ON col.object_id = ic.object_id
                                                                AND col.column_id = ic.column_id
                                        WHERE           ic.object_id = ind.object_id
                                                        AND ic.index_id = ind.index_id
                                                        AND ic.is_included_column = 1
                                        ORDER BY        ic.index_column_id
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS i(content)
                OUTER APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name))
                                        FROM            sys.index_columns AS ic
                                        INNER JOIN      (
                                                                SELECT  object_id,
                                                                        column_id,
                                                                        CASE
                                                                                WHEN name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN @new_column_name
                                                                                ELSE name COLLATE DATABASE_DEFAULT
                                                                        END AS name
                                                                FROM    sys.columns
                                                        ) AS col ON col.object_id = ic.object_id
                                                                AND col.column_id = ic.column_id
                                        WHERE           ic.object_id = ind.object_id
                                                        AND ic.index_id = ind.index_id
                                                        AND ic.partition_ordinal >= 1
                                        ORDER BY        ic.partition_ordinal
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS p(content)
                OUTER APPLY     (
                                        SELECT          CONCAT(N', ', QUOTENAME(col.name COLLATE DATABASE_DEFAULT))
                                        FROM            sys.index_columns AS ic
                                        INNER JOIN      (
                                                                SELECT  object_id,
                                                                        column_id,
                                                                        CASE
                                                                                WHEN name COLLATE DATABASE_DEFAULT = @column_name AND @new_column_name > N'' THEN @new_column_name
                                                                                ELSE name COLLATE DATABASE_DEFAULT
                                                                        END AS name
                                                                FROM    sys.columns
                                                        ) AS col ON col.object_id = ic.object_id
                                                                AND col.column_id = ic.column_id
                                        WHERE           ic.object_id = ind.object_id
                                                        AND ic.index_id = ind.index_id
                                                        AND ic.key_ordinal = 0
                                                        AND ic.is_included_column = 0
                                                        AND ic.partition_ordinal= 0
                                        ORDER BY        ic.partition_ordinal
                                        FOR XML         PATH(N''),
                                                        TYPE
                                ) AS o(content)
                OUTER APPLY     (
                                        SELECT          CONCAT(', DATA_COMPRESSION = ', dc.type_desc, ' ON PARTITIONS (', STUFF(CAST(p.info AS NVARCHAR(MAX)), 1, 2, N''), N')')
                                        FROM            (
                                                                VALUES  (0, N'NONE'),
                                                                        (1, N'ROW'),
                                                                        (2, N'PAGE'),
                                                                        (3, N'COLUMNSTORE'),
                                                                        (4, N'COLUMNSTORE_ARCHIVE')
                                                        ) AS dc(data_compression, type_desc)
                                        OUTER APPLY     (
                                                                SELECT          CONCAT(N', ', par.partition_number)
                                                                FROM            sys.partitions AS par
                                                                WHERE           par.object_id = ind.object_id
                                                                                AND par.index_id = ind.index_id
                                                                                AND par.data_compression = dc.data_compression
                                                                ORDER BY        par.partition_number
                                                                FOR XML         PATH(N''),
                                                                                TYPE
                                                        ) AS p(info)
                                        WHERE           p.info IS NOT NULL
                                        FOR XML         PATH(''),
                                                        TYPE
                                ) AS c(content)
                WHERE           ind.type >= 1
                                AND     (
                                                @column_name IS NULL
                                                OR @column_name IS NOT NULL AND CHARINDEX(QUOTENAME(@column_name), CAST(k.content AS NVARCHAR(MAX))) >= CAST(1 AS INT)
                                                OR @column_name IS NOT NULL AND CHARINDEX(QUOTENAME(@column_name), CAST(i.content AS NVARCHAR(MAX))) >= CAST(1 AS INT)
                                                OR @column_name IS NOT NULL AND CHARINDEX(QUOTENAME(@column_name), CAST(p.content AS NVARCHAR(MAX))) >= CAST(1 AS INT)
                                                OR @column_name IS NOT NULL AND CHARINDEX(QUOTENAME(@column_name), CAST(o.content AS NVARCHAR(MAX))) >= CAST(1 AS INT)
                                                OR @column_name IS NOT NULL AND CHARINDEX(QUOTENAME(@column_name), CAST(c.content AS NVARCHAR(MAX))) >= CAST(1 AS INT)
                                                OR ind.has_filter = CAST(1 AS BIT) AND @column_name IS NOT NULL AND CHARINDEX(QUOTENAME(@column_name), ind.filter_definition COLLATE DATABASE_DEFAULT) >= CAST(1 AS BIGINT)
                                        )
        )
        SELECT          cte.schema_name,
                        cte.table_name,
                        cte.index_name,
                        cte.page_count,
                        cte.index_type_major,
                        cte.index_type_minor,
                        cte.is_disabled,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteIndexes AS cte
        CROSS APPLY     (
                                SELECT  N'crix' AS action_code,
                                        CASE
                                                -- Nonclustered hash index
                                                WHEN cte.index_type_major = CAST(7 AS TINYINT) AND cte.is_unique = CAST(1 AS BIT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD INDEX ', QUOTENAME(cte.index_name), N' UNIQUE NONCLUSTERED HASH (', cte.key_columns, N') WITH (', cte.bucket_count, N');')
                                                WHEN cte.index_type_major = CAST(7 AS TINYINT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD INDEX ', QUOTENAME(cte.index_name), N' NONCLUSTERED HASH (', cte.key_columns, N') WITH (', cte.bucket_count, N');')
                                                -- Nonclustered columnstore index
                                                WHEN cte.index_type_major = CAST(6 AS TINYINT) THEN CONCAT(N'CREATE NONCLUSTERED COLUMNSTORE INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' (', cte.include_columns, N') WITH (', cte.drop_existing, N', ', cte.compression_delay, N', ', cte.data_compression, N')', cte.data_space_definition, N';')
                                                -- Clustered columnstore index
                                                WHEN cte.index_type_major = CAST(5 AS TINYINT) AND cte.is_memory_optimized = CAST(1 AS BIT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD INDEX ', QUOTENAME(cte.index_name), N' CLUSTERED COLUMNSTORE WITH (', cte.compression_delay, N')', cte.data_space_definition, N';')
                                                WHEN cte.index_type_major = CAST(5 AS TINYINT) THEN CONCAT(N'CREATE CLUSTERED COLUMNSTORE INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' WITH (', cte.drop_existing, N', ', cte.compression_delay, N', ', cte.data_compression, N')', cte.data_space_definition, N';')
                                                -- Spatial index
                                                WHEN cte.index_type_major = CAST(4 AS TINYINT) THEN CONCAT(N'CREATE SPATIAL INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' (', cte.other_columns, N') USING ', QUOTENAME(cte.tessellation_scheme), N' WITH (', cte.bounding_box, N', ', cte.grids, N', ', cte.cells_per_object, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.drop_existing, N', ', cte.online, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N')', cte.data_space_definition, ';')
                                                -- XML primary index
                                                WHEN cte.index_type_major = CAST(3 AS TINYINT) AND cte.index_type_minor = CAST(0 AS TINYINT) THEN CONCAT(N'CREATE PRIMARY XML INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' (', cte.other_columns, N') WITH (', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.drop_existing, N', ', cte.online, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N');')
                                                -- XML index
                                                WHEN cte.index_type_major = CAST(3 AS TINYINT) AND cte.index_type_minor = CAST(1 AS TINYINT) THEN CONCAT(N'CREATE XML INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' (', cte.other_columns, N') USING XML INDEX ', QUOTENAME(cte.primary_xml_index_name), N' FOR ', QUOTENAME(cte.xml_type_desc), N' WITH (', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.drop_existing, N', ', cte.online, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N');')
                                                -- Nonclustered index
                                                WHEN cte.index_type_major = CAST(2 AS TINYINT) AND cte.is_primary_key = CAST(1 AS BIT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.index_name), N' PRIMARY KEY NONCLUSTERED (', cte.key_columns, N')', CASE WHEN cte.include_columns > N'' THEN N' INCLUDE (' + cte.include_columns + N')' ELSE N'' END, cte.filter_definition, N' WITH (', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                WHEN cte.index_type_major = CAST(2 AS TINYINT) AND cte.is_unique_constraint = CAST(1 AS BIT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.index_name), N' UNIQUE NONCLUSTERED (', cte.key_columns, N')', CASE WHEN cte.include_columns > N'' THEN N' INCLUDE (' + cte.include_columns + N')' ELSE N'' END, cte.filter_definition, N' WITH (', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                WHEN cte.index_type_major = CAST(2 AS TINYINT) AND cte.is_unique = CAST(1 AS BIT) THEN CONCAT(N'CREATE UNIQUE NONCLUSTERED INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' (', cte.key_columns, N')', CASE WHEN cte.include_columns > N'' THEN N' INCLUDE (' + cte.include_columns + N')' ELSE N'' END, cte.filter_definition, N' WITH (', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                WHEN cte.index_type_major = CAST(2 AS TINYINT) THEN CONCAT(N'CREATE NONCLUSTERED INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' (', key_columns, N')', CASE WHEN cte.include_columns > N'' THEN N' INCLUDE (' + cte.include_columns + N')' ELSE N'' END, cte.filter_definition, N' WITH (', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                -- Clustered index
                                                WHEN cte.index_type_major = CAST(1 AS TINYINT) AND cte.is_primary_key = CAST(1 AS BIT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.index_name), N' PRIMARY KEY CLUSTERED (', cte.key_columns, N') WITH(', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                WHEN cte.index_type_major = CAST(1 AS TINYINT) AND cte.is_unique_constraint = CAST(1 AS BIT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ADD CONSTRAINT ', QUOTENAME(cte.index_name), N' UNIQUE CLUSTERED (', cte.key_columns, N') WITH(', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                WHEN cte.index_type_major = CAST(1 AS TINYINT) AND cte.is_unique = CAST(1 AS BIT) THEN CONCAT(N'CREATE UNIQUE CLUSTERED INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N'(', cte.key_columns, N') WITH(', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                WHEN cte.index_type_major = CAST(1 AS TINYINT) THEN CONCAT(N'CREATE CLUSTERED INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N'(', cte.key_columns, N') WITH(', cte.online, N', ', cte.pad_index, N', ', cte.statistics_norecompute, N', ', cte.sort_in_tempdb, N', ', cte.ignore_dup_key, N', ', cte.allow_row_locks, N', ', cte.allow_page_locks, N', ', cte.fill_factor, N')', cte.data_space_definition, ';')
                                                ELSE N''
                                        END AS sql_text

                                UNION ALL

                                SELECT  N'drix',
                                        CASE
                                                WHEN cte.is_memory_optimized = CAST(1 AS BIT) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP INDEX ', QUOTENAME(cte.index_name), N');')
                                                WHEN CAST(1 AS BIT) IN (cte.is_primary_key, cte.is_unique_constraint) THEN CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DROP CONSTRAINT ', QUOTENAME(cte.index_name), N' WITH (', cte.online, N');')
                                                ELSE CONCAT(N'DROP INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' WITH (', cte.online, N');')
                                        END

                                UNION ALL

                                SELECT  N'diix',
                                        CONCAT(N'ALTER INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DISABLE;')

                                UNION ALL

                                SELECT  N'enix',
                                        CONCAT(N'ALTER INDEX ', QUOTENAME(cte.index_name), N' ON ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' REBUILD PARTITION = ', CASE WHEN cte.data_space_type = 'PS' THEN CAST(par.partition_number AS NVARCHAR(11)) ELSE N'ALL' END, N';')
                                FROM    sys.partitions AS par
                                WHERE   par.object_id = cte.table_id
                                        AND par.index_id = cte.index_id
                ) AS act (action_code, sql_text);
GO
