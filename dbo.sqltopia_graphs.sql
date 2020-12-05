IF OBJECT_ID(N'dbo.sqltopia_graphs', N'TF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_graphs() RETURNS @return TABLE (i INT) AS BEGIN RETURN; END;');
GO
ALTER FUNCTION dbo.sqltopia_graphs
(
        @objtype NVARCHAR(8) = N'COLUMN'
)
/*
        sqltopia_graphs v2.0.0 (2021-01-01)
        (C) 2009-2021, Peter Larsson
*/
RETURNS @return TABLE
        (
                schema_id INT NOT NULL,
                schema_name SYSNAME NOT NULL,
                table_id INT NOT NULL,
                table_name SYSNAME NOT NULL,
                column_id INT NOT NULL,
                column_name SYSNAME NOT NULL,
                PRIMARY KEY CLUSTERED
                (
                        table_id,
                        column_id
                ),
                graph_id INT NOT NULL,
                parent_count INT NOT NULL,
                child_count INT NOT NULL
        )
AS
BEGIN
        IF @objtype IS NULL OR @objtype NOT IN (N'TABLE', N'COLUMN')
                RETURN;
        ELSE
                SET     @objtype = UPPER(@objtype);

        -- Get all columns
        INSERT          @return
                        (
                                schema_id,
                                schema_name,
                                table_id,
                                table_name,
                                column_id,
                                column_name,
                                graph_id,
                                parent_count,
                                child_count
                        )
        SELECT          sch.schema_id,
                        sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                        tbl.object_id AS table_id,
                        tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                        col.column_id AS column_id,
                        col.name COLLATE DATABASE_DEFAULT AS column_name,
                        DENSE_RANK() OVER (ORDER BY sch.name COLLATE DATABASE_DEFAULT, tbl.name COLLATE DATABASE_DEFAULT, CASE WHEN @objtype = N'TABLE' THEN N'' ELSE col.name COLLATE DATABASE_DEFAULT END) AS graph_id,
                        0 AS parent_count,
                        0 AS child_count
        FROM            sys.columns AS col
        INNER JOIN      sys.tables AS tbl ON tbl.object_id = col.object_id
                                AND tbl.type COLLATE DATABASE_DEFAULT = N'U'
        INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id;

        -- Loop until no more columns are found with foreign keys
        WHILE ROWCOUNT_BIG() >= 1
                WITH cteGraphs(table_id, column_id, graph_id, parent_count, child_count)
                AS (
                        SELECT          fkc.parent_object_id AS table_id,
                                        fkc.parent_column_id AS column_id,
                                        ret.graph_id,
                                        1 AS parent_count,
                                        0 AS child_count
                        FROM            @return AS ret
                        INNER JOIN      sys.foreign_key_columns AS fkc ON fkc.referenced_object_id = ret.table_id
                                                AND fkc.referenced_column_id = ret.column_id

                        UNION

                        SELECT          fkc.referenced_object_id AS table_id,
                                        fkc.referenced_column_id AS column_id,
                                        ret.graph_id,
                                        0 AS parent_count,
                                        1 AS child_count
                        FROM            @return AS ret
                        INNER JOIN      sys.foreign_key_columns AS fkc ON fkc.parent_object_id = ret.table_id
                                                AND fkc.parent_column_id = ret.column_id
                )
                UPDATE          ret
                SET             ret.graph_id = cte.graph_id,
                                ret.parent_count += cte.parent_count,
                                ret.child_count += cte.child_count
                FROM            @return AS ret
                INNER JOIN      cteGraphs AS cte ON cte.table_id = ret.table_id
                                        AND (cte.column_id = ret.column_id OR @objtype = N'TABLE')
                                        AND cte.graph_id < ret.graph_id;

        -- Finished
        RETURN;
END;
GO
