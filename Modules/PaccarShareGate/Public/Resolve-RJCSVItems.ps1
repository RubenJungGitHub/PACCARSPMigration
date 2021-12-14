using module MigrationClasses
function Resolve-RJCSVItems {
    [OutputType([System.Collections.Generic.List[MigrationRunClass]])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeLine)][PSCustomObject]$items
    )
    process {
        $returnlist = [System.Collections.Generic.List[MigrationUnitClass]]::new()
        $TargetSite1 = $Items | Where-Object { $_."Target site 1" -ne "" } |  Select-Object -Property "Target site 1"
        $TargetSite2 = $Items | Where-Object { $_."Target site 2" -ne "" } |  Select-Object -Property "Target site 2"
        $TargetSite3 = $Items | Where-Object { $_."Target site 3" -ne "" } |  Select-Object -Property "Target site 3"
        Write-progress "Resolve Targetsite one MUs "
        #$Target1Sources = [System.Collections.Generic.List[PSCustomObject]]::new
        $TargetSite1Sources = $Items | Where-Object { $_."Source 1 MUS" -ne "" -And $_."SCOPE 1" -ne "" }
        $TargetSite2Sources = $Items | Where-Object { $_."Source 2 MUS" -ne "" -And $_."SCOPE 2" -ne "" }
        $TargetSite3Sources = $Items | Where-Object { $_."Source 3 MUS" -ne "" -And $_."SCOPE 3" -ne "" }
        $TargetSite1Sources | ForEach-Object { $_."Target site 1" = $TargetSite1[0]."Target Site 1" }
        $TargetSite2Sources | ForEach-Object { $_."Target site 2" = $TargetSite2[0]."Target Site 2" }
        $TargetSite3Sources | ForEach-Object { $_."Target site 3" = $TargetSite3[0]."Target Site 3" }
        #Process source one
        ForEach ($TSMU in $TargetSite1Sources) {
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TSMU."Target Site 1"
            $MU.CompleteSourceURL = $TSMU.'Source 1 MUS'
            $MU.TargetLibPrefixGiven= $TSMU.'MU Prefix 1'
            $MU.DuplicateTargetLibPrefix = $TSMU.'MU Prefix 1'
            $MU.SourceURL, $MU.ListURL , $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 1 MUS'
            $Mu.UniquePermissions = !!$TSMU."UP 1"
            $MU.MergeMUS = !!$TSMU."Merge 1"
            $Mu.Scope = $TSMU."Scope 1"
            $returnlist.Add($MU)
        }
        ForEach ($TSMU in $TargetSite2Sources) {
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TSMU."Target Site 2"
            $MU.CompleteSourceURL = $TSMU.'Source 2 MUS'
            $MU.TargetLibPrefixGiven= $TSMU.'MU Prefix 2'
            $MU.DuplicateTargetLibPrefix = $TSMU.'MU Prefix 2'
            $MU.SourceURL, $MU.ListURL, $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 2 MUS'
            $Mu.UniquePermissions = !!$TSMU."UP 2"
            $MU.MergeMUS = !!$TSMU."Merge 2"
            $Mu.Scope = $TSMU."Scope 2"
            $returnlist.Add($MU)
        }
        ForEach ($TSMU in $TargetSite3Sources) {
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TSMU."Target Site 3"
            $MU.CompleteSourceURL = $TSMU.'Source 3 MUS'
            $MU.TargetLibPrefixGiven= $TSMU.'MU Prefix 3'
            $MU.DuplicateTargetLibPrefix = $TSMU.'MU Prefix 3'
            $MU.SourceURL, $MU.ListURL, $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 3 MUS'
            $Mu.UniquePermissions = !!$TSMU."UP 3"
            $MU.MergeMUS = !!$TSMU."Merge 3"
            $Mu.Scope = $TSMU."Scope 3"
            $returnlist.Add($MU)
        }
        #Double check duplicate targetlib and prefix entries
        $DuplicatePrefixes = $returnList | Group-object -Property DestinationURL, ListTitle, DuplicateTargetLibPrefix | Where-Object { $_.Count -gt 1 }
        ForEach ($DuplicatePrefixMU in $DuplicatePrefixes) {
            ForEach ($DuplicatePrefix in $DuplicatePrefixMU.Group) {
                #Limit on 50 chares for renaming lists using ShareGatePowershell GUID TOO LARGE
                #DuplicatePrefix.DuplicateTargetLibPrefix = -Join ($DuplicatePrefix.DuplicateTargetLibPrefix , (New-Guid))
                #WorkAround
                $DuplicatePrefix.DuplicateTargetLibPrefix = -Join ($DuplicatePrefix.DuplicateTargetLibPrefix , ( Get-Random -Minimum 0 -Maximum 10000000 ).ToString('00000000'))

            }
        }

        foreach ($MU in $Returnlist) {
            $Mu.NodeID = $Settings.NodeID
            $MU.EnvironmentName = $Settings.Environment
            if ($MU.DuplicateTargetLibPrefix -eq '') {
                $MU.DuplicateTargetLibPrefix = $MU.ListURL -replace ($MU.ListTitle, "") -Replace ("/", "") -Replace ("-", "") -Replace (" ", "")                 
            }
        }
        return $returnlist  
    }
}