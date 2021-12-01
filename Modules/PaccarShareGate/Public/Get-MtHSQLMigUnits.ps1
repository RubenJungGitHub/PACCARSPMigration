using module MigrationClasses

function Get-MtHSQLMigUnits {
    [CmdletBinding()]
    Param(
        
        [parameter(mandatory = $false)] [String] $Url,
        [parameter(mandatory = $false)] [String] $CompleteSourceUrl,
        [parameter(mandatory = $false)] [int] $MigUnitId,
        [switch] $all
    )
    # query to get all entries from the MigrationUnits Table of a specific SiteCollection
    if (!$All) {
        if ($MigUnitId) {
            $sql = @"
    SELECT EnvironmentName, MigUnitId, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
    FROM MigrationUnits
    WHERE MigUnitId = $MigUnitId;
"@
        }
        elseif ($URL) {
            $sql = @"
    SELECT EnvironmentName, MigUnitId, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
    FROM MigrationUnits
    WHERE SourceUrl = '$Url'
    ORDER BY MigUnitId;
"@
        }
        elseif ($CompleteSourceURL) {
            $sql = @"
    SELECT EnvironmentName, MigUnitId, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
    FROM MigrationUnits
    WHERE CompleteSourceURL= '$CompleteSourceUrl'
    ORDER BY MigUnitId;
"@
        }
    }
    else {
        $sql = @'
        SELECT EnvironmentName, MigUnitId, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
        FROM MigrationUnits
        ORDER BY MigUnitId;
'@
    }
    $dbitems = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    return $dbitems | Resolve-MtHMUClass
}
