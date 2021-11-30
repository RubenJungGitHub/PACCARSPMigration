# added line to prevent drop errors
# https://blog.sqlauthority.com/2010/02/11/sql-server-alter-database-dbname-set-single_user-with-rollback-immediate/
function New-MtHSQLDatabase {
    [CmdletBinding()]
    Param(
    )
    $Sql = @"
        USE master
        IF EXISTS 
        (
            SELECT name FROM master.dbo.sysdatabases 
            WHERE name = '$($Settings.SQLDetails.Database)'
        )
        BEGIN
            SELECT 'Database already exists' As Message
        END
        ELSE
        BEGIN
            CREATE DATABASE $($Settings.SQLDetails.Database)
            SELECT 'New Database is Created' As Message
        END
        GO
        USE $($Settings.SQLDetails.Database)
"@
    $output = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Query $Sql
    write-verbose $output.Message
    if ($output.Message -eq 'New Database is Created') {
        Invoke-MtHSQLQueryFile -FileName "$(Get-MtHGitDirectory)\SQLStatements\EmptyDatabase.sql"
        write-verbose "Tables created"
    }
    else {
        # this warning is coming to often ???
        write-warning "Trying to recreate an existing database"
    }
    return ($output.Message -eq 'New Database is Created')
}