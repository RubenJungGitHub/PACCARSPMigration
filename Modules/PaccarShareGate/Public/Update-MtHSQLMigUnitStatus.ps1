function Update-MtHSQLMigUnitStatus {
    [CmdletBinding()]
    Param(     
        [parameter(mandatory = $true)] [PSCustomObject] $Item,
        [switch]$updateitemcount,
        [switch]$UpdateDestination
    )
    #query to update an entry in the MigrationUnits Table
    if ($updateitemcount) {
        $sql = @"
        UPDATE MigrationUnits
        SET MUStatus = '$($Item.MUStatus)', NextAction = '$($Item.NextAction)', NodeId = $($Item.NodeId), ItemCount = $($Item.ItemCount)
        WHERE MigUnitId = $($Item.MigUnitId);
"@
    }
    elseif ($UpdateDestination) {
        $sql = @"
        UPDATE MigrationUnits
        SET DestinationUrl = '$($Item.DestinationUrl)'
        WHERE MigUnitId = $($Item.MigUnitId);
"@     
    }
    else {
        $sql = @"
        UPDATE MigrationUnits
        SET MUStatus = '$($Item.MUStatus)', NextAction = '$($Item.NextAction)', NodeId = $($Item.NodeId)
        WHERE MigUnitId = $($Item.MigUnitId);
"@ 
    }
    Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
}