IF OBJECT_ID(N'dbo.sqltopia_hierarchy', N'TF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_hierarchy() RETURNS @return TABLE (i INT) AS BEGIN RETURN; END;');
GO
ALTER FUNCTION dbo.sqltopia_hierarchy
(
        @objtype NVARCHAR(8) = N'COLUMN'
)
/*
        sqltopia_hierarchy v1.7.2 (2020-11-15)
        (C) 2012-2020, Peter Larsson
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
                position INT NOT NULL
        )
AS
BEGIN
        IF @objtype IS NULL OR @objtype NOT IN (N'TABLE', N'COLUMN')
                RETURN;

        -- Local helper variable
        DECLARE @position INT = 1;

        -- Insert all top level tables
        INSERT  @return
                (
                        schema_id,
                        schema_name,
                        table_id,
                        table_name,
                        column_id,
                        column_name,
                        position
                )
        SELECT  0 AS schema_id,
                N'' AS schema_name,
                referenced_object_id AS table_id,
                N'' AS table_name,
                referenced_column_id AS column_id,
                N'' AS column_name,
                1 AS position
        FROM    sys.foreign_key_columns

        EXCEPT

        SELECT  0 AS schema_id,
                N'' AS schema_name,
                parent_object_id AS table_id,
                N'' AS table_name,
                parent_column_id AS column_id,
                N'' AS column_name,
                1 AS position
        FROM    sys.foreign_key_columns;

        -- Loop until no more columns are found with foreign keys
        WHILE ROWCOUNT_BIG() >= 1
                BEGIN
                        SET     @position += 1;

                        MERGE   @return AS tgt
                        USING   (
                                        SELECT DISTINCT 0 AS schema_id,
                                                        N'' AS schema_name,
                                                        fkc.parent_object_id AS table_id,
                                                        N'' AS table_name,
                                                        fkc.parent_column_id AS column_id,
                                                        N'' AS column_name,
                                                        @position AS position
                                        FROM            @return AS ret
                                        INNER JOIN      sys.foreign_key_columns AS fkc ON fkc.referenced_object_id = ret.table_id
                                                                AND fkc.referenced_column_id = ret.column_id
                                        WHERE           ret.position = @position - 1
                                ) AS src ON src.table_id = tgt.table_id
                                        AND src.column_id = tgt.column_id
                        WHEN    NOT MATCHED BY TARGET
                                THEN    INSERT  (
                                                        schema_id,
                                                        schema_name,
                                                        table_id,
                                                        table_name,
                                                        column_id,
                                                        column_name,
                                                        position
                                                )
                                        VALUES  (
                                                        src.schema_id,
                                                        src.schema_name,
                                                        src.table_id,
                                                        src.table_name,
                                                        src.column_id,
                                                        src.column_name,
                                                        src.position
                                                );
                END;

        -- Insert remaining columns and update existing columns
        MERGE   @return AS tgt
        USING   (
                        SELECT          sch.schema_id,
                                        sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                        tbl.object_id AS table_id,
                                        tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                        col.column_id,
                                        col.name COLLATE DATABASE_DEFAULT AS column_name,
                                        @position AS position
                        FROM            sys.schemas AS sch
                        INNER JOIN      sys.tables AS tbl ON tbl.schema_id = sch.schema_id
                        INNER JOIN      sys.columns AS col ON col.object_id = tbl.object_id
                ) AS src ON src.table_id = tgt.table_id
                        AND src.column_id = tgt.column_id
        WHEN    MATCHED
                THEN    UPDATE
                        SET     tgt.schema_id = src.schema_id,
                                tgt.schema_name = src.schema_name,
                                tgt.table_name = src.table_name,
                                tgt.column_name = src.column_name
        WHEN    NOT MATCHED BY TARGET
                THEN    INSERT  (
                                        schema_id,
                                        schema_name,
                                        table_id,
                                        table_name,
                                        column_id,
                                        column_name,
                                        position
                                )
                        VALUES  (
                                        src.schema_id,
                                        src.schema_name,
                                        src.table_id,
                                        src.table_name,
                                        src.column_id,
                                        src.column_name,
                                        src.position
                                );

        -- Recalculate position if using TABLE only
        IF @objtype = N'TABLE'
                BEGIN
                        WITH ctePositions(position, rnk)
                        AS (
                                SELECT  position,
                                        MAX(position) OVER (PARTITION BY table_id) AS rnk
                                FROM    @return
                        )
                        UPDATE  ctePositions
                        SET     position = rnk
                        WHERE   position <> rnk;

                        WITH ctePositions(position, rnk)
                        AS (
                                SELECT  position,
                                        DENSE_RANK() OVER (ORDER BY position) AS rnk
                                FROM    @return
                        )
                        UPDATE  ctePositions
                        SET     position = rnk
                        WHERE   position <> rnk;
                END;

        -- Finished
        RETURN;
END;
GO
