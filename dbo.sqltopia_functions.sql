IF OBJECT_ID(N'dbo.sqltopia_functions', N'IF') IS NULL
        EXEC(N'CREATE FUNCTION dbo.sqltopia_functions() RETURNS TABLE AS RETURN SELECT NULL AS Yak;');
GO
ALTER FUNCTION dbo.sqltopia_functions
(
        @schema_name SYSNAME,
        @function_name SYSNAME,
        @column_name SYSNAME
)
RETURNS TABLE
AS
RETURN  WITH cteFunctions(schema_id, schema_name, function_id, function_name, function_definition)
        AS (
                SELECT DISTINCT sch.schema_id,
                                sch.name AS schema_name,
                                obj.object_id AS function_id,
                                obj.name AS function_name,
                                sqm.definition
                FROM            sys.columns AS col
                INNER JOIN      sys.types AS typ ON typ.user_type_id = col.user_type_id
                                        AND typ.is_user_defined = 1
                INNER JOIN      sys.types AS wrk ON wrk.user_type_id = col.system_type_id
                                        AND wrk.name IN ('char', 'nchar', 'nvarchar', 'varchar')
                INNER JOIN      sys.objects AS obj ON obj.object_id = col.object_id
                                        AND obj.type = 'TF'
                                        AND (obj.name COLLATE DATABASE_DEFAULT = @function_name OR @function_name IS NULL)
                INNER JOIN      sys.schemas AS sch ON sch.schema_id = obj.schema_id
                                        AND (sch.name COLLATE DATABASE_DEFAULT = @schema_name OR @schema_name IS NULL)
                INNER JOIN      sys.sql_modules AS sqm ON sqm.object_id = obj.object_id
                WHERE           col.name COLLATE DATABASE_DEFAULT = @column_name
                                OR @column_name IS NULL
        )
        SELECT          cte.schema_id, 
                        cte.schema_name, 
                        cte.function_id, 
                        cte.function_name,
                        CAST(act.action_code AS NCHAR(4)) AS action_code,
                        act.sql_text
        FROM            cteFunctions AS cte
        CROSS APPLY     (
                                VALUES  (
                                                N'drfu',
                                                CONCAT(N'DROP FUNCTION ', QUOTENAME(cte.schema_name), N'.', QUOTENAME(cte.function_name), N';')
                                        ),
                                        (
                                                N'crfu',
                                                CONCAT(cte.function_definition, N';')
                                        )
                        ) AS act(action_code, sql_text);
GO
