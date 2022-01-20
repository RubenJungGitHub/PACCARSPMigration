# This function returns all registerred Library items to check deleted
# Declared obsolete Ruben Jung 16-09-2021. (to be removed)
function Register-RJListID {
    [CmdletBinding()]
    Param(        
        [parameter(mandatory = $true)] [String]$scrSite,
        [parameter(mandatory = $true)] [String]$dstSite,
        [parameter(mandatory = $true)] [PSCustomObject]$Lists,
        [parameter(mandatory = $false)] [String]$RenamedList
    )
    $ListRelPath
    foreach ($List in $Lists) {
        $GetPNPListName = $RenamedList
        if ('' -eq $GetPNPListName) {
            $GetPNPListName = $list.Title
        }
        #Make sure the correct source url is referenced
        if ( $List.GetType() -eq [MigrationUnitClass])
        {
            $ListRelPath = $List.ListURL
        }
        else {
            #Drop Trailing /
            $ListRelPath = $List.RootFolder.Substring(0, $List.RootFolder.Length-1)
        }
        $pnplst = Get-PnPList -Identity $GetPNPListName
        $sql = @"
        UPDATE MigrationUnits
        SET ListID = CASE WHEN ('$($pnplst.ID)' IS NULL) THEN 'NOT DETECTED IN TARGET' WHEN ('$($pnplst.ID)' = '') THEN 'NOT DETECTED IN TARGET' ELSE '$($pnplst.ID)' END
        WHERE ListURL = '$($ListRelPath)'
"@
        Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    }
}