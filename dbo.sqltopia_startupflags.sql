CREATE OR ALTER PROCEDURE dbo.sqltopia_startupflags
(
        @action NVARCHAR(4),    -- get, add, drop
        @flags NVARCHAR(MAX)
)
AS

-- Prevent unwanted resultsets back to client
SET NOCOUNT ON;

BEGIN TRY
        -- Local helper variables
        DECLARE @InstanceName NVARCHAR(4000),
                @Registry NVARCHAR(MAX) = N'Windows Registry Editor Version 5.00',
                @Value NVARCHAR(4000),
                @Data NVARCHAR(4000);

        -- Local helper table
        DECLARE @parameters TABLE
                (
                        id INT IDENTITY(0, 1) NOT NULL,
                        action NVARCHAR(4) NULL,
                        value NVARCHAR(4000) NOT NULL,
                        data NVARCHAR(4000) NOT NULL
                );

        -- Validate user supplied parameter values
        SELECT  @action = LOWER(@action),
                @flags = LOWER(@flags);

        -- Insert existing startup flags
        INSERT  @parameters
                (
                        value,
                        data
                )
        EXEC    master.sys.xp_instance_regenumvalues    N'HKEY_LOCAL_MACHINE',
                                                        N'Software\Microsoft\Microsoft SQL Server\MSSQLServer\Parameters';

        -- Exit here if only want to get current flags
        IF @action = N'get'
                BEGIN
                        SELECT  par.value,
                                par.data
                        FROM    @parameters AS par
                        WHERE   par.data LIKE N'-T%';

                        RETURN;
                END;

        -- Insert the wanted startup flags
        WITH cteFlags(Flag)
        AS (
                SELECT DISTINCT TRIM('t -' FROM f.value)
                FROM            STRING_SPLIT(@Flags, N',') AS f
        )
        MERGE   @Parameters AS tgt
        USING   (
                        SELECT  @action AS action,
                                N'SQLArg' AS Value,
                                CONCAT(N'-T', cte.Flag) AS Data
                        FROM    cteFlags AS cte
                        WHERE   TRY_CAST(cte.Flag AS INT) IS NOT NULL
                ) AS src ON src.Data = tgt.Data
        WHEN    MATCHED AND src.action = N'drop'
                THEN    UPDATE
                        SET     tgt.action = src.action
        WHEN    NOT MATCHED BY TARGET AND src.action = N'add'
                THEN    INSERT  (
                                        action,
                                        Value,
                                        Data
                                )
                        VALUES  (
                                        src.action,
                                        src.Value,
                                        src.Data
                                );

        -- Get default instance name
        EXEC    master.sys.xp_instance_regread  N'HKEY_LOCAL_MACHINE',
                                                N'Software\Microsoft\Microsoft SQL Server',
                                                N'',
                                                @InstanceName OUTPUT;

        EXEC    master.sys.xp_regread   N'HKEY_LOCAL_MACHINE',
                                        N'Software\Microsoft\Microsoft SQL Server\Instance Names\SQL',
                                        @InstanceName,
                                        @InstanceName OUTPUT;

        -- Start building registry file content
        SET     @Registry += CONCAT(NCHAR(13), NCHAR(10), NCHAR(13), NCHAR(10), N'[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\', @InstanceName, '\MSSQLServer\Parameters]');

        IF @action = N'add'
                BEGIN
                        SELECT  @Registry += CONCAT(NCHAR(13), NCHAR(10), STRING_AGG(CONCAT(N'"', par.Value, par.id, N'" = "', par.Data, N'"'), NCHAR(13) + CHAR(10)) WITHIN GROUP (ORDER BY id), N'')
                        FROM    @Parameters AS par
                        WHERE   action = N'add';
                END;
        ELSE IF @action = N'drop'
                BEGIN
                        SELECT  @Registry += CONCAT(NCHAR(13), NCHAR(10), STRING_AGG(CONCAT(N'"', par.Value, N'" = -'), NCHAR(13) + CHAR(10)) WITHIN GROUP (ORDER BY id), N'')
                        FROM    @Parameters AS par
                        WHERE   action = N'drop';
                END;

        -- Display the content of registry file
        PRINT @Registry;
END TRY
BEGIN CATCH
        THROW;
END CATCH;
