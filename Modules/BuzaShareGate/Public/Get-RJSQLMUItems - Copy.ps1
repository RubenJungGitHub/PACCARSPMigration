#This function returns all registerred Library items to check deleted
#Declared obsolete Ruben Jung 16-09-2021. (to be removed)
function Get-RJSQLMUItems 
{
    [CmdletBinding()]
    Param(
        
        [parameter(mandatory = $true)] [int] $MigUnitID,
        [parameter(mandatory = $true)] [ValidateSet("existsinsource", "deletedinsource", "deletedintarget")][String] $ItemStatus,
        [switch]$alltobedeleted
    )
    # query to get all entries from the MigrationUnits Table of a specific SiteCollection
If(!$alltobedeleted)
{
$sql = @"
SELECT LibItemGUIDAndFileName, MigUnitId, LibItemFileRef, LibItemFileLeafRef, LibItemStatus
FROM ListMUItems
WHERE MigUnitId = $MigUnitID And LibItemStatus = '$ItemStatus';
"@
}
else 
{
$sql = @"
SELECT LibItemGUIDAndFileName, MigUnitId, LibItemFileRef, LibItemFileLeafRef, LibItemStatus
FROM ListMUItems
WHERE LibItemStatus = '$ItemStatus'
ORDER BY MigUnitID
"@  
}
    return (Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql) | Resolve-RJMIClass -Source SQL
}