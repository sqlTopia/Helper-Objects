IF OBJECT_ID(N'dbo.sqltopia_schema_table_column', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_schema_table_column() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
CREATE FUNCTION dbo.sqltopia_schema_table_column
(
        @schema_name SYSNAME,
        @table_name SYSNAME,
        @column_name SYSNAME
)
/*
        sqltopia_schema_table_column v1.7.5 (2020-12-03)
        (C) 2009-2020, Peter Larsson
*/
RETURNS TABLE
AS
RETURN  SELECT          sch.schema_id,
                        tbl.object_id AS table_id,
                        col.column_id
        FROM            sys.schemas AS sch
        INNER JOIN      sys.tables AS tbl ON tbl.schema_id = sch.schema_id
                                AND tbl.name COLLATE DATABASE_DEFAULT = @table_name
        INNER JOIN      sys.columns AS col ON col.object_id = tbl.object_id
                                AND col.name COLLATE DATABASE_DEFAULT = @column_name
        WHERE           sch.name COLLATE DATABASE_DEFAULT = @schema_name;
GO
