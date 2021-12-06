using module MigrationClasses
function Resolve-RJCSVItems {
    [OutputType([System.Collections.Generic.List[MigrationRunClass]])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeLine)][PSCustomObject]$items
    )
    process {
        $returnlist = [System.Collections.Generic.List[MigrationUnitClass]]::new()
        $TargetSite1 = $Items | Where-Object  {$_."Target site 1" -ne ""} |  Select-Object -Property "Target site 1"
        $TargetSite2 = $Items | Where-Object  {$_."Target site 2" -ne ""} |  Select-Object -Property "Target site 2"
        $TargetSite3 = $Items | Where-Object  {$_."Target site 3" -ne ""} |  Select-Object -Property "Target site 3"
        Write-progress "Resolve Targetsite one MUs "
        #$Target1Sources = [System.Collections.Generic.List[PSCustomObject]]::new
        $TargetSite1Sources = $Items | Where-Object  {$_."Source 1 MUS" -ne "" -And $_."SCOPE 1" -ne ""}
        $TargetSite2Sources = $Items | Where-Object  {$_."Source 2 MUS" -ne "" -And $_."SCOPE 2" -ne ""}
        $TargetSite3Sources = $Items | Where-Object  {$_."Source 3 MUS" -ne "" -And $_."SCOPE 3" -ne ""}
        $TargetSite1Sources | ForEach-Object {$_."Target site 1" = $TargetSite1[0]."Target Site 1"}
        $TargetSite2Sources | ForEach-Object {$_."Target site 2" = $TargetSite2[0]."Target Site 2"}
        $TargetSite3Sources | ForEach-Object {$_."Target site 3" = $TargetSite3[0]."Target Site 3"}
        #Process source one
        ForEach($TSMU in $TargetSite1Sources)
        {
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TSMU."Target Site 1"
            $MU.CompleteSourceURL = $TSMU.'Source 1 MUS'
            $MU.SourceURL, $MU.ListURL , $MU.ListTitle= ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 1 MUS'
            $Mu.UniquePermissions = !!$TSMU."UP 1"
            $Mu.Scope = $TSMU."Scope 1"
            $returnlist.Add($MU)
        }
        ForEach($TSMU in $TargetSite2Sources)
        {
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TSMU."Target Site 2"
            $MU.CompleteSourceURL = $TSMU.'Source 2 MUS'
            $MU.SourceURL, $MU.ListURL, $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 2 MUS'
            $Mu.UniquePermissions = !!$TSMU."UP 2"
            $Mu.Scope = $TSMU."Scope 2"
            $returnlist.Add($MU)
        }
        ForEach($TSMU in $TargetSite3Sources)
        {
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TSMU."Target Site 3"
            $MU.CompleteSourceURL = $TSMU.'Source 3 MUS'
            $MU.SourceURL, $MU.ListURL, $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 3 MUS'
            $Mu.UniquePermissions =!!$TSMU."UP 3"
            $Mu.Scope = $TSMU."Scope 3"
            $returnlist.Add($MU)
        }
        #Double check duplicate targetlib entries
        foreach ($MU in $Returnlist)
        {
            $MU.EnvironmentName = $Settings.Environment
            $MU.DuplicateTargetLibPrefix = $MU.ListURL -replace($MU.ListTitle,"") -Replace("/","") -Replace("-","") -Replace(" ", "") 
            $Mu.NodeID = $Settings.NodeID
            #Check if targetlib in destination exists 
        }
        return $returnlist  
    }
}