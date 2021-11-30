using Module MigrationClasses
# get MigRuns, test included in integration test
function Get-MtHSQLMigRuns {
    [CmdletBinding()]
    Param(
        
        [parameter(mandatory = $false)] $MigRunId = -1,
        [parameter(mandatory = $false)] $MigUnitId = -1,
        [switch] $all
    )
    # query to get all entries from the MigrationUnits Table of a specific SiteCollection
    if (!$All) {
        if ($MigRunId -ne -1) {
            $sql = @"
        SELECT MigUnitId, StartTime, Processed, Result, SGSessionId, RunTimeInSec, Details, MigRunId
        FROM MigrationRuns
        WHERE MigRunId = $MigRunId;
"@
        }
        elseif ($MigUnitId -ne -1) {
                $sql = @"
            SELECT MigUnitId, StartTime, Processed, Result, SGSessionId, RunTimeInSec, Details, MigRunId
            FROM MigrationRuns
            WHERE MigUnitId = $MigUnitId;
"@
        }
    }
    else {
        $sql = @'
        SELECT MigUnitId, StartTime, Processed, Result, SGSessionId, RunTimeInSec, Details, MigRunId
        FROM MigrationRuns;
'@
    }
    return Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql | Resolve-MtHMRClass
}