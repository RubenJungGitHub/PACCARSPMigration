# update database after a migration run
function Register-MtHSQLMigRunResults {
    [CmdletBinding()]
    Param(
        [parameter(mandatory = $true)] [String] $Result,
        [parameter(mandatory = $true)] [decimal] $RunTimeInSec,
        [parameter(mandatory = $true)] [String] $SGSessionId,
        [parameter(mandatory = $true)] [int] $MigRunId,
        [parameter(mandatory = $false)] [String] $Details
    )
    # query 3a : Migration runs ended result to success or fail
    $sql = @"
        UPDATE MigrationRuns
        SET RunTimeInSec = $RunTimeInSec, Result = '$Result', SGSessionId = '$SGSessionId', Details = '$Details'
        OUTPUT Inserted.MigUnitId
        WHERE MigrationRuns.MigRunId = $MigRunId;
"@
    $MigUnitId = (Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql)[0]
    if ($Result -eq 'success' -or $Result -eq 'deleted') {
        $sql = @"
            UPDATE MigrationUnits
            SET NextAction = 'none'
            WHERE MigUnitId = $MigUnitId;
"@
        Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    }
    if ($Result -eq 'failed') {
        $sql = @"
            UPDATE MigrationUnits
            SET MUStatus = 'failed', NextAction = 'none'
            WHERE MigUnitId = $MigUnitId;
"@
        Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    }
}
