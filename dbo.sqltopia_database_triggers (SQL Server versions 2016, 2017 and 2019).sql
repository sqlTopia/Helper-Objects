IF OBJECT_ID(N'dbo.sqltopia_database_triggers', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_database_triggers() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_database_triggers
(        
)
RETURNS TABLE
AS
RETURN  WITH cteTriggers(trigger_id, trigger_name, trigger_definition)
        AS (
                SELECT          trg.object_id AS trigger_id,
                                trg.name COLLATE DATABASE_DEFAULT AS trigger_name,
                                sqm.definition COLLATE DATABASE_DEFAULT AS trigger_definition
                FROM            sys.sql_modules AS sqm
                INNER JOIN      sys.triggers AS trg ON trg.object_id = sqm.object_id
                WHERE           trg.parent_class_desc = N'DATABASE'
        )
        SELECT          cte.trigger_id,
                        cte.trigger_name,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteTriggers AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drdt',
                                                CONCAT(N'DROP TRIGGER IF EXISTS ', QUOTENAME(cte.trigger_name), N' ON DATABASE;')
                                        ),
                                        (
                                                N'crdt',
                                                CONCAT(N'CREATE TRIGGER ', QUOTENAME(cte.trigger_name), N' ON DATABASE FOR ', cte.trigger_definition, N';')
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
