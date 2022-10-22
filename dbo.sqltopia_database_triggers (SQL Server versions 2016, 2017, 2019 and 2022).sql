IF OBJECT_ID(N'dbo.sqltopia_database_triggers', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_database_triggers() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_database_triggers
(        
)
RETURNS TABLE
AS
RETURN  WITH cteDatabaseTriggers(trigger_id, trigger_name, trigger_definition, is_disabled, is_ms_shipped)
        AS (
                SELECT          trg.object_id AS trigger_id,
                                trg.name COLLATE DATABASE_DEFAULT AS trigger_name,
                                sqm.definition COLLATE DATABASE_DEFAULT AS trigger_definition,
                                trg.is_disabled,
                                trg.is_ms_shipped
                FROM            sys.sql_modules AS sqm
                INNER JOIN      sys.triggers AS trg ON trg.object_id = sqm.object_id
                WHERE           trg.parent_class_desc = N'DATABASE'
        )
        SELECT          cte.trigger_id,
                        cte.trigger_name,
                        is_disabled,
                        is_ms_shipped, 
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteDatabaseTriggers AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drdt',
                                                CONCAT(N'DROP TRIGGER IF EXISTS ', QUOTENAME(cte.trigger_name), N' ON DATABASE;')
                                        ),
                                        (
                                                N'crdt',
                                                CONCAT(cte.trigger_definition, N';')
                                        ),
                                        (
                                                N'didt',
                                                CONCAT(N'DISABLE TRIGGER ', QUOTENAME(cte.trigger_name), N' ON DATABASE;')
                                        ),
                                        (
                                                N'endt',
                                                CONCAT(N'ENABLE TRIGGER ', QUOTENAME(cte.trigger_name), N' ON DATABASE;')
                                        )
                        ) AS act(action_code, sql_text);
GO
