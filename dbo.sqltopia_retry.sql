IF OBJECT_ID(N'dbo.sqltopia_retry', N'P') IS NULL
        EXEC(N'CREATE PROCEDURE dbo.sqltopia_retry AS');
GO
ALTER PROCEDURE dbo.sqltopia_retry
(
        @query_text NVARCHAR(MAX),
        @max_retry_count TINYINT = 3
)
/*
        sqltopia_retry v1.7.5 (2020-12-03)
        (C) 2009-2020, Peter Larsson
*/
AS

-- Prevent unwanted resultsets back to client
SET NOCOUNT ON;

-- Local helper variable
DECLARE @current_retry TINYINT = 0;

-- Validate user supplied parameter values
IF @max_retry_count IS NULL
        SET     @max_retry_count = 3;

IF @max_retry_count > 25
        SET     @max_retry_count = 25;

-- Retry until no more retries are available
WHILE @current_retry <= @max_retry_count
        BEGIN
                BEGIN TRY
                        EXEC    (@query_text);

                        BREAK;
                END TRY
                BEGIN CATCH
                        IF ERROR_NUMBER() = 1204                -- SQL Server cannot obtain a lock resource.
                                SET     @current_retry += 1;
                        ELSE IF ERROR_NUMBER() = 1205           -- Resources are accessed in conflicting order on separate transactions, causing a deadlock.
                                SET     @current_retry += 1;
                        ELSE IF ERROR_NUMBER() = 1222           -- Another transaction held a lock on a required resource longer than this query could wait for it.
                                SET     @current_retry += 1;
                        ELSE
                                BEGIN
                                        THROW;

                                        RAISERROR(N'A new complication has occured. Please report error number to sp_AlterColumn developer.', 18, 1);

                                        RETURN  -1000;
                                END;
                END CATCH;
        END;

IF @current_retry > @max_retry_count
        BEGIN
                RAISERROR(N'Maximum retry count %s is reached.', 18, 1, @max_retry_count) WITH NOWAIT;
                                
                RETURN  -2000;
        END;
GO