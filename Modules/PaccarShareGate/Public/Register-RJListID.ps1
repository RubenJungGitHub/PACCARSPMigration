# This function returns all registerred Library items to check deleted
# Declared obsolete Ruben Jung 16-09-2021. (to be removed)
function Register-RJListID {
    [CmdletBinding()]
    Param(        
        [parameter(mandatory = $true)] [String]$scrSite,
        [parameter(mandatory = $true)] [String]$dstSite,
        [parameter(mandatory = $true)] [String[]]$ListNames
    )
 
    foreach ($Listname in $ListNames) {
        $List = Get-PnPList -Identity $ListName
        $CompleteSourceURLhttp  = -Join($srcSite.Address.AbsoluteUri.Replace('https','http'),$List.RootFolder.ServerRelativeUrl.Split('/')[($List.RootFolder.ServerRelativeUrl.Split('/').Length-1)],'/')
        $CompleteSourceURLhttps  = -Join($srcSite.Address.AbsoluteUri,$List.RootFolder.ServerRelativeUrl.Split('/')[($List.RootFolder.ServerRelativeUrl.Split('/').Length-1)],'/')
        $sql = @"
        UPDATE MigrationUnits
        SET ListID = CASE WHEN ('$($List.ID)' IS NULL) THEN 'NOT DETECTED IN TARGET' WHEN ('$($List.ID)' = '') THEN 'NOT DETECTED IN TARGET' ELSE '$($List.ID)' END
        WHERE CompleteSourceURL = '$($CompleteSourceURLhttp)' OR  CompleteSourceURL = '$($CompleteSourceURLhttps)'
"@
        Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    }
}