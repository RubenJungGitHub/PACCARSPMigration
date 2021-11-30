using module MigrationClasses
# get all lists and sites from one SP sitecollection URL, no test 
function Get-MtHOneSPSiteLists {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)][String]$Url
    )
    $returnvalue = [System.Collections.Generic.List[MigrationUnitClass]]::new()
    $newentry = [MigrationUnitClass]@{
        EnvironmentName = $settings.Environment
        SourceUrl       = $Url
        Scope           = 'site'
    }
    $returnvalue.add($newentry)
    $excludedlists = ('SiteAssets', 'SitePages', 'Style_x0020_Library')
    $connection = Connect-MtHSharePoint -URL $Url
    if ($connection) {
        Get-PnPWeb -Includes LastItemModifiedDate, RoleAssignments | Out-Null
        $lists = Get-PnPList | Where-Object { $_.hidden -eq $false -and $_.EntityTypeName -notin $excludedlists -and $_.ItemCount -ne 0 }
        write-verbose "registered $url with $($lists.count) Lists/Libraries"
        $lists | ForEach-Object {
            $newentry = [MigrationUnitClass]@{
                EnvironmentName = $settings.Environment
                SourceUrl       = $Url
                ListUrl         = $_.RootFolder.ServerRelativeUrl
                ListTitle       = $_.Title
                ListId          = $_.Id
                ListTemplate    = $_.BaseTemplate
                Scope           = 'list'
                ItemCount       = $_.ItemCount
            }
            $returnvalue.add($newentry)
        }
    }
    return $returnvalue
}
