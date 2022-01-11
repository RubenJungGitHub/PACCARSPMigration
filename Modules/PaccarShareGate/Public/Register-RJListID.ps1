# This function returns all registerred Library items to check deleted
# Declared obsolete Ruben Jung 16-09-2021. (to be removed)
function Register-RJListID {
    [CmdletBinding()]
    Param(        
        [parameter(mandatory = $true)] [String]$dstSite,
        [parameter(mandatory = $true)] [String[]]$ListNames
    )
 
    foreach ($Listname in $ListNames) {
        If ($ListName -eq 'CetrificatesTestPrefix') {
             $a = 1 }
        $List = Get-PnPList -Identity $ListName
        $sql = @"
        UPDATE MigrationUnits
        SET ListID = CASE WHEN ('$($List.ID)' IS NULL) THEN 'NOT DETECTED IN TARGET' WHEN ('$($List.ID)' = '') THEN 'NOT DETECTED IN TARGET' ELSE '$($List.ID)' END
        WHERE  DestinationURl= '$($dstSite)' And (ListTitle = '$($Listname)' OR ListTitleWithPrefix  = '$($Listname)')
"@
        Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    }
}