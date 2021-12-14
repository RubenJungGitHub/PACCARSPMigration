using module MigrationClasses
function Rename-RJListsTitlePrefix 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)] [PSCustomObject[]]$Lists,
        [Parameter(Mandatory = $True)] [MigrationUnitClass[]]$MUS,
        [Parameter(Mandatory = $True)] [string]$dstSiteUrl
    )
    Connect-MtHSharePoint -URL $dstSiteUrl | Out-Null
    foreach ($List in $Lists) 
    {
        Write-Verbose "Connect top target $($dstSiteUrl) for list existance check"
        $ListsForRenaming = [System.Collections.Generic.List[MigrationUnitClass]]::new()
        $ListsForMerge = $MUS | Where-Object {$_.MergeMUS -eq  $true} 
        #Select all Items with givenPrefix
        $ListsWithGivenPrefix = $MUS | Where-Object {$_.TargetLibPrefixGiven -ne ''}
        $ListsPresentInTarget =Get-PnPList  | Where-Object { $_.Title -In $MUS.ListTitle } | Where-Object {$_.Title -NotIn $ListsWithGivenPrefix.ListTitle} 
        #Remove Lists to be merged from present in target
        $ListsPresentInTarget = $ListsPresentInTarget | Where-Object { $_.ListTitle -NotIn $ListsForMerge.ListTitle } 
        $RenamedLists = $MUS | Where-Object {$_.ListTitle -In $ListsPresentInTarget.ListTitle -or $_.ListTitle -In $ListsWithGivenPrefix.ListTitle}
        $ListsForRenaming.Add($RenamedLists)
    }
    return $ListsForRenaming
}