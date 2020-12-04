IF OBJECT_ID(N'dbo.sqltopia_column_datatype', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_column_datatype() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_column_datatype
(
        @table_id INT,
        @column_id INT
)
/*
        sqltopia_column_datatype v2.0.0 (2021-01-01)
        (C) 2009-2021, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  SELECT          typ.name COLLATE DATABASE_DEFAULT AS datatype_name,
                        CASE
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'nvarchar', N'varbinary', N'varchar') AND col.max_length = -1 THEN 'MAX'
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'binary', N'char', N'varbinary', N'varchar') THEN CAST(col.max_length AS CHAR(4))
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'nchar', N'nvarchar') THEN CAST(col.max_length / 2 AS CHAR(4))
                                ELSE CAST(NULL AS CHAR(4))
                        END AS max_length,
                        CASE
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'decimal', N'numeric') THEN col.precision
                                ELSE CAST(NULL AS TINYINT)
                        END AS precision,
                        CASE
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'decimal', N'numeric') THEN col.scale
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'datetime2', N'datetimeoffset', N'time') THEN col.scale
                                ELSE CAST(NULL AS TINYINT)
                        END AS scale,
                        CASE
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'text', N'ntext') THEN col.collation_name
                                WHEN typ.name COLLATE DATABASE_DEFAULT IN (N'char', N'varchar', N'nchar', N'nvarchar') THEN col.collation_name
                                ELSE NULL
                        END AS collation_name,
                        CASE
                                WHEN typ.name COLLATE DATABASE_DEFAULT = N'xml' THEN xsc.name COLLATE DATABASE_DEFAULT
                                ELSE NULL
                        END AS xml_collection_name,
                        CASE
                                WHEN col.is_nullable = 1 THEN N'yes'
                                ELSE N'no'
                        END AS is_nullable,
                        df.name COLLATE DATABASE_DEFAULT AS default_name,
                        ru.name COLLATE DATABASE_DEFAULT AS rule_name,
                        typ.is_user_defined
        FROM            sys.columns AS col
        INNER JOIN      sys.types AS typ ON col.user_type_id = typ.user_type_id
        LEFT JOIN       sys.xml_schema_collections AS xsc ON xsc.xml_collection_id = col.xml_collection_id
                                AND xsc.xml_collection_id <> 0
        LEFT JOIN       sys.objects AS df ON df.object_id = col.default_object_id
                                AND df.object_id <> 0
                                AND df.type COLLATE DATABASE_DEFAULT = 'D'
        LEFT JOIN       sys.objects AS ru ON ru.object_id = col.rule_object_id
                                AND ru.object_id <> 0
                                AND ru.type COLLATE DATABASE_DEFAULT = 'R'
        WHERE           col.object_id = @table_id
                        AND col.column_id = @column_id;
GO
