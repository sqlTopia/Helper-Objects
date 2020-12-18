IF OBJECT_ID(N'dbo.sqltopia_table_triggers', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_table_triggers() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_table_triggers
(
        @schema_name SYSNAME,
        @table_name SYSNAME
)
RETURNS TABLE
AS
RETURN  WITH cteTriggers(schema_id, schema_name, table_id, table_name, trigger_id, trigger_name, trigger_definition, is_disabled, is_ms_shipped)
        AS (
                SELECT          sch.schema_id,
                                sch.name COLLATE DATABASE_DEFAULT AS schema_name,
                                tbl.object_id AS table_id,
                                tbl.name COLLATE DATABASE_DEFAULT AS table_name,
                                trg.object_id AS trigger_id,
                                trg.name COLLATE DATABASE_DEFAULT AS trigger_name,
                                sqm.definition COLLATE DATABASE_DEFAULT AS trigger_definition,
                                trg.is_disabled, 
                                trg.is_ms_shipped
                FROM            sys.sql_modules AS sqm
                INNER JOIN      sys.triggers AS trg ON trg.object_id = sqm.object_id
                INNER JOIN      sys.tables AS tbl ON tbl.object_id = trg.parent_id
                                        AND (tbl.name COLLATE DATABASE_DEFAULT = @table_name OR @table_name IS NULL)
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = tbl.schema_id
                                        AND (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL)
                WHERE           trg.parent_class_desc = N'OBJECT_OR_COLUMN'
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.table_id, 
                        cte.table_name,
                        cte.trigger_id,
                        cte.trigger_name,
                        cte.is_disabled, 
                        cte.is_ms_shipped,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteTriggers AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drtg',
                                                CONCAT(N'DROP TRIGGER IF EXISTS ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.trigger_name), N';')
                                        ),
                                        (
                                                N'crtg',
                                                CONCAT(cte.trigger_definition, N';')
                                        ),
                                        (
                                                N'ditg',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' DISABLE TRIGGER ', QUOTENAME(cte.trigger_name), N';')
                                        ),
                                        (
                                                N'entg',
                                                CONCAT(N'ALTER TABLE ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.table_name), N' ENABLE TRIGGER ', QUOTENAME(cte.trigger_name), N';')
                                        )
                        ) AS act(action_code, sql_text);
GO
