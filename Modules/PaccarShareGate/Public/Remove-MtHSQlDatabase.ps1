# added line to prevent drop errors
# https://blog.sqlauthority.com/2010/02/11/sql-server-alter-database-dbname-set-single_user-with-rollback-immediate/

function Remove-MtHSQLDatabase {
    [CmdletBinding()]
    Param(
    )
    if ($settings.SQLDetails.DeleteDB) { 
        $Sql = @"
        USE master
        IF EXISTS 
        (
            SELECT name FROM master.dbo.sysdatabases 
            WHERE name = '$($Settings.SQLDetails.Database)'
        )
        BEGIN    
            ALTER DATABASE $($Settings.SQLDetails.Database)
            SET SINGLE_USER WITH ROLLBACK IMMEDIATE
            DROP DATABASE $($Settings.SQLDetails.Database)
            SELECT 'Database Deleted' As Message
        END
        ELSE BEGIN
            SELECT 'Database does not exist' As Message
        END
"@
        $output = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Query $Sql
        Write-Verbose "Database: $($Settings.SQLDetails.Database) : $($output.Message)"
    } 
    else {
        Write-Verbose "Database may not be removed: Delete DB is False"
    }
}