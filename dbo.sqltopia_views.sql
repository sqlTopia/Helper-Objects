IF OBJECT_ID(N'dbo.sqltopia_views', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_views() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_views
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME
)
RETURNS TABLE
RETURN  -- Work with nested schemabound views
        WITH cteViews(dependency_level, referencing_id, referencing_minor_id)
        AS (
                SELECT          1 AS dependency_level,
                                sed.referencing_id,
                                sed.referencing_minor_id
                FROM            sys.sql_expression_dependencies AS sed
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = sed.referenced_id
                                        AND tbl.name COLLATE DATABASE_DEFAULT = @table_name
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                        AND sch.name COLLATE DATABASE_DEFAULT  = @schema_name
                INNER JOIN      sys.columns AS col ON col.object_id = tbl.object_id
                                        AND col.name COLLATE DATABASE_DEFAULT  = @column_name
                WHERE           col.column_id = sed.referenced_minor_id
                                AND sed.is_schema_bound_reference = 1

                UNION ALL

                SELECT          cte.dependency_level + 1 AS dependency_level,
                                sed.referencing_id,
                                sed.referencing_minor_id
                FROM            cteViews AS cte
                INNER JOIN      sys.sql_expression_dependencies AS sed ON sed.referenced_id = cte.referencing_id
                                        AND sed.referenced_minor_id = cte.referencing_minor_id
                                        AND sed.is_schema_bound_reference = 1
                INNER JOIN      sys.views AS vw ON vw.object_id = sed.referencing_id
        )
        SELECT          sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                        vw.name COLLATE DATABASE_DEFAULT AS view_name,
                        cte.dependency_level,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            (
                                SELECT DISTINCT dependency_level,
                                                referencing_id AS view_id
                                FROM            cteViews
                        ) AS cte
        INNER JOIN      sys.views AS vw ON vw.object_id = cte.view_id
        INNER JOIN      sys.schemas AS sch ON sch.schema_id = vw.schema_id
        INNER JOIN      sys.sql_modules AS sqm ON sqm.object_id = cte.view_id
        CROSS APPLY     (
                                VALUES  (
                                                N'drvw',
                                                CONCAT(N'DROP VIEW ', QUOTENAME(sch.name COLLATE DATABASE_DEFAULT), N'.', QUOTENAME(vw.name COLLATE DATABASE_DEFAULT), N';')
                                        ),
                                        (
                                                N'crvw',
                                                CONCAT(sqm.definition COLLATE DATABASE_DEFAULT, N';')
                                        )
                        ) AS act(action_code, sql_text);
GO
