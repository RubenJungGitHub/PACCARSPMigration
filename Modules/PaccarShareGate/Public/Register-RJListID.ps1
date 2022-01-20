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
 
    foreach ($List in $Lists) {
        $GetPNPListName = $RenamedList
        if('' -eq $GetPNPListName)
        {
            $GetPNPListName = $list.ListTitle
        }
        $pnplst = Get-PnPList -Identity $GetPNPListName
        <#$CompleteSourceURLhttp  = -Join($srcSite.Address.AbsoluteUri.Replace('https','http'),$List.RootFolder.ServerRelativeUrl.Split('/')[($List.RootFolder.ServerRelativeUrl.Split('/').Length-1)],'/').Replace('%20',' ')
        $CompleteSourceURLhttps  = -Join($srcSite.Address.AbsoluteUri,$List.RootFolder.ServerRelativeUrl.Split('/')[($List.RootFolder.ServerRelativeUrl.Split('/').Length-1)],'/').Replace('%20',' ')
        #>
        $sql = @"
        UPDATE MigrationUnits
        SET ListID = CASE WHEN ('$($pnplst.ID)' IS NULL) THEN 'NOT DETECTED IN TARGET' WHEN ('$($pnplst.ID)' = '') THEN 'NOT DETECTED IN TARGET' ELSE '$($pnplst.ID)' END
        WHERE ListURL = '$($List.ListURL)'
"@
        Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    }
}