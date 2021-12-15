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
        Write-Verbose "Connect to target $($dstSiteUrl) for list existance check"
        $ListsForRenaming = [System.Collections.Generic.List[MigrationUnitClass]]::new()
        #Filter Lists for merge with prefix # Require rename 
        $ListsForMergeWithPrefix  = $MUS | Where-Object {$_.MergeMUS -eq  $true -and $_.TargetLibPrefixGiven -ne ''} 
        
        #filter lists with PrefixGiven not for merge #Require rename
        $ListsWitPrefix = $MUS | Where-Object {$_.TargetLibPrefixGiven -ne '' -and $_ -NotIn $ListsForMergeWithPrefix}
 
        #Filter remaininglists 
        $RemainingLists = $MUS | Where-Object {$_ -NotIn $ListsWitPrefix}
        
        #$ListsPresentInTarget =Get-PnPList  | Where-Object {$_.Title -In $RemainingLists.ListTitle -or  $_.Title.Replace(' ','') -in $RemainingLists.ListTitle -or $_.Title -In -Join($RemainingLists.ListTitle,$RemainingLists.DuplicateTargetLibPrefix) -or  $_.Title.Replace(' ','') -in -Join($RemainingLists.ListTitle,$RemainingLists.DuplicateTargetLibPrefix)}
        #Check Lists  present in target # Require rename  
        $ListsPresentInTarget =Get-PnPList  | Where-Object {$_.Title -In $RemainingLists.ListTitle -or  $_.Title.Replace(' ','') -in $RemainingLists.ListTitle}

        #All MUS that require renamin Lists to be renamed
        $RenamedLists = $MUS | Where-Object {$_.ListTitle -In $ListsPresentInTarget.ListTitle -or $_.ListTitle -In $ListsWitPrefix.ListTitle -or $_.ListTitle -in  $ListsForMergeWithPrefix.ListTitle}
        $RenamedLists | ForEach-Object {$ListsForRenaming.Add($_)}
    }
    return $ListsForRenaming
}