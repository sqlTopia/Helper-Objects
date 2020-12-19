IF OBJECT_ID(N'dbo.sqltopia_graphs', N'TF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_graphs() RETURNS @return TABLE (i INT) AS BEGIN RETURN; END;');
GO
ALTER FUNCTION dbo.sqltopia_graphs
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME
)
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
                table_graph_id INT NOT NULL,
                column_graph_id INT NOT NULL,
                is_connected BIT NOT NULL
        )
AS
BEGIN
        -- Get initial columns
        INSERT          @return
                        (
                                schema_id,
                                schema_name,
                                table_id,
                                table_name,
                                column_id,
                                column_name,
                                table_graph_id,
                                column_graph_id,
                                is_connected
                        )
        SELECT          sch.schema_id,
                        sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                        tbl.object_id AS table_id,
                        tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                        col.column_id AS column_id,
                        col.name COLLATE DATABASE_DEFAULT AS column_name,
                        DENSE_RANK() OVER (ORDER BY CASE WHEN f.is_connected = 1 THEN 1 ELSE 2 END, sch.name COLLATE DATABASE_DEFAULT, tbl.name COLLATE DATABASE_DEFAULT) AS table_graph_id,
                        ROW_NUMBER() OVER (ORDER BY CASE WHEN f.is_connected = 1 THEN 1 ELSE 2 END, sch.name COLLATE DATABASE_DEFAULT, tbl.name COLLATE DATABASE_DEFAULT, col.name COLLATE DATABASE_DEFAULT) AS column_graph_id,
                        f.is_connected
        FROM            sys.columns AS col
        INNER JOIN      sys.tables AS tbl ON tbl.object_id = col.object_id
        INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
        CROSS APPLY     (
                                VALUES  (
                                                CASE
                                                        WHEN (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL) AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL) AND (col.name COLLATE DATABASE_DEFAULT = @column_name OR @column_name IS NULL) THEN 1
                                                        ELSE 0
                                                END
                                        )
                        ) AS f(is_connected);

        -- Loop until no more connections are found with foreign keys
        WHILE ROWCOUNT_BIG() >= 1
                BEGIN
                        WITH cteGraphs(table_id, column_id, table_graph_id, column_graph_id)
                        AS (
                                SELECT          fkc.referenced_object_id AS table_id,
                                                fkc.referenced_column_id AS column_id,
                                                ret.table_graph_id,
                                                ret.column_graph_id
                                FROM            @return AS ret
                                INNER JOIN      sys.foreign_key_columns AS fkc ON fkc.parent_object_id = ret.table_id
                                                        AND fkc.parent_column_id = ret.column_id
                                WHERE           ret.is_connected = 1

                                UNION

                                SELECT          fkc.parent_object_id AS table_id,
                                                fkc.parent_column_id AS column_id,
                                                ret.table_graph_id,
                                                ret.column_graph_id
                                FROM            @return AS ret
                                INNER JOIN      sys.foreign_key_columns AS fkc ON fkc.referenced_object_id = ret.table_id
                                                        AND fkc.referenced_column_id = ret.column_id
                                WHERE           ret.is_connected = 1
                        )
                        UPDATE          ret
                        SET             ret.table_graph_id =    CASE 
                                                                        WHEN cte.table_graph_id < ret.table_graph_id THEN cte.table_graph_id 
                                                                        ELSE ret.table_graph_id 
                                                                END,
                                        ret.column_graph_id =   CASE 
                                                                        WHEN cte.column_id = ret.column_id AND cte.column_graph_id < ret.column_graph_id THEN cte.column_graph_id 
                                                                        ELSE ret.column_graph_id 
                                                                END,
                                        ret.is_connected =      CASE 
                                                                        WHEN @column_name IS NULL AND cte.table_graph_id < ret.table_graph_id THEN 1
                                                                        WHEN @column_name IS NOT NULL AND cte.column_id = ret.column_id AND cte.column_graph_id < ret.column_graph_id THEN 1
                                                                        ELSE ret.is_connected
                                                                END
                        FROM            @return AS ret
                        INNER JOIN      cteGraphs AS cte ON cte.table_id = ret.table_id
                        WHERE           cte.table_graph_id < ret.table_graph_id
                                        OR cte.column_id = ret.column_id AND cte.column_graph_id < ret.column_graph_id;
                END;

        -- Make graph ids more appealing
        WITH cteGraphs(table_graph_id, table_rnk, column_graph_id, column_rnk)
        AS (
                SELECT  table_graph_id, 
                        DENSE_RANK() OVER (ORDER BY table_graph_id) AS table_rnk, 
                        column_graph_id, 
                        DENSE_RANK() OVER (ORDER BY column_graph_id) AS column_rnk
                FROM    @return
        )
        UPDATE  cteGraphs
        SET     table_graph_id = table_rnk,
                column_graph_id = column_rnk;
        
        RETURN;
END;
GO
