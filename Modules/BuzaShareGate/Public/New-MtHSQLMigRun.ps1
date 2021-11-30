# run defined SQL queries against the database. Only Queries with zero or one parameter $itemnr can be defined here.
function New-MtHSQLMigRun {
    [CmdletBinding()]
    Param(       
        [parameter(mandatory = $true)] [string] $MigrationType,
        [parameter(mandatory = $false)] [int] $ItemNr,
        [parameter(mandatory = $false)] [switch] $Fake 
    )
    if ($fake) {
        $kind = 'fake'
    } 
    else {
        $kind = 'real'
    }
    $sql = @"
            INSERT INTO MigrationRuns
            (MigUnitId, StartTime, Processed, Result, Kind, MigrationType,  RunTimeInSec, SGSessionId, Details)
            OUTPUT Inserted.MigRunId
            VALUES
            ($ItemNr, SYSDATETIME (), 'false', 'started','$kind', '$MigrationType',  0, 0, '');
"@
    # returns the ID of the created item in the MigrunTable, which can be updated after the run
    return (Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql)[0]
}