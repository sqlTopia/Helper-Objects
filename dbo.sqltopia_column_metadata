IF OBJECT_ID(N'dbo.sqltopia_column_metadata', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_column_metadata() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_column_metadata
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME
)
RETURNS TABLE
AS
RETURN  SELECT          sch.schema_id,
                        sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                        tbl.object_id AS table_id,
                        tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                        tbl.type COLLATE DATABASE_DEFAULT AS table_type,
                        col.column_id,
                        col.name COLLATE DATABASE_DEFAULT AS column_name,
                        usr.name COLLATE DATABASE_DEFAULT AS datatype_name,
                        CASE
                                WHEN usr.name COLLATE DATABASE_DEFAULT IN (N'nvarchar', N'varbinary', N'varchar') AND col.max_length = -1 THEN CAST(N'MAX' AS NVARCHAR(4))
                                WHEN usr.name COLLATE DATABASE_DEFAULT IN (N'binary', N'char', N'varbinary', N'varchar') THEN CAST(col.max_length AS NVARCHAR(4))
                                WHEN usr.name COLLATE DATABASE_DEFAULT IN (N'nchar', N'nvarchar') THEN CAST(col.max_length / 2 AS NVARCHAR(4))
                                ELSE CAST(NULL AS NVARCHAR(4))
                        END AS max_length,
                        CASE 
                                WHEN usr.name COLLATE DATABASE_DEFAULT IN (N'decimal', N'numeric') THEN col.precision
                                ELSE CAST(NULL AS TINYINT)
                        END AS precision,
                        CASE 
                                WHEN usr.name COLLATE DATABASE_DEFAULT IN (N'datetime2', N'datetimeoffset', N'decimal', N'numeric', N'time') THEN col.scale
                                ELSE CAST(NULL AS TINYINT)
                        END AS scale,
                        col.collation_name COLLATE DATABASE_DEFAULT AS collation_name,
                        CASE
                                WHEN col.is_nullable = CAST(1 AS BIT) THEN CAST(N'yes' AS NVARCHAR(3))
                                ELSE CAST(N'no' AS NVARCHAR(3))
                        END AS is_nullable,
                        xsc.name COLLATE DATABASE_DEFAULT AS xml_collection_name,
                        def.name COLLATE DATABASE_DEFAULT AS datatype_default_name,
                        rul.name COLLATE DATABASE_DEFAULT AS datatype_rule_name
        FROM            sys.schemas AS sch
        INNER JOIN      sys.tables AS tbl ON tbl.schema_id = sch.schema_id
                                AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL)
        INNER JOIN      sys.columns AS col ON col.object_id = tbl.object_id
                                AND (col.name COLLATE DATABASE_DEFAULT = @column_name OR @column_name IS NULL)
        INNER JOIN      sys.types AS usr ON usr.user_type_id = col.user_type_id
        LEFT JOIN       sys.xml_schema_collections AS xsc ON xsc.xml_collection_id = col.xml_collection_id
                                AND xsc.xml_collection_id <> 0
        LEFT JOIN       sys.objects AS def ON def.object_id = usr.default_object_id
                                AND def.type COLLATE DATABASE_DEFAULT = 'D'
                                AND usr.default_object_id <> 0
        LEFT JOIN       sys.objects AS rul ON rul.object_id = usr.rule_object_id
                                AND rul.type COLLATE DATABASE_DEFAULT = 'R'
                                AND usr.rule_object_id <> 0
        WHERE           sch.name COLLATE DATABASE_DEFAULT = @schema_name
                        OR @schema_name IS NULL;
