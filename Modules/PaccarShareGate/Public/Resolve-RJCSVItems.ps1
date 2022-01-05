using module MigrationClasses
function Resolve-RJCSVItems {
    [OutputType([System.Collections.Generic.List[MigrationRunClass]])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeLine)][PSCustomObject]$items
    )
    process {
        $returnlist = [System.Collections.Generic.List[MigrationUnitClass]]::new()
        $SitePermissions =  $Items | Where-Object { $_."SitePermissionsSource" -ne "" } |  Select-Object -Property "SitePermissionsSource"
        $TargetSite1 = $Items | Where-Object { $_."Target site 1" -ne "" } |  Select-Object -Property "Target site 1"
        $TargetSite2 = $Items | Where-Object { $_."Target site 2" -ne "" } |  Select-Object -Property "Target site 2"
        $TargetSite3 = $Items | Where-Object { $_."Target site 3" -ne "" } |  Select-Object -Property "Target site 3"
        Write-progress "Resolve Targetsite one MUs "
        $TargetSite1Sources = $Items | Where-Object { $_."Source 1 MUS" -ne "" -And $_."SCOPE 1" -ne "" }
        $TargetSite2Sources = $Items | Where-Object { $_."Source 2 MUS" -ne "" -And $_."SCOPE 2" -ne "" }
        $TargetSite3Sources = $Items | Where-Object { $_."Source 3 MUS" -ne "" -And $_."SCOPE 3" -ne "" }
        Write-Progress "Only get unique source URLS from input"
        $TargetSite1SourcesGrouped = $TargetSite1Sources | Group-Object -Property 'Source 1 MUS'
        $TargetSite2SourcesGrouped = $TargetSite2Sources | Group-Object -Property 'Source 2 MUS'
        $TargetSite3SourcesGrouped = $TargetSite3Sources | Group-Object -Property 'Source 3 MUS'

        #Process source one
        ForEach ($TSG in $TargetSite1SourcesGrouped) {
            $TSMU = $TSG.Group[0]
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TargetSite1.'Target Site 1'
            $MU.CompleteSourceURL = $TSMU.'Source 1 MUS'
            $MU.TargetLibPrefixGiven = $TSMU.'MU Prefix 1'
            $MU.DuplicateTargetLibPrefix = $TSMU.'MU Prefix 1'
            $MU.SourceURL, $MU.ListURL , $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 1 MUS'
            $Mu.UniquePermissions = !!$TSMU."UP 1"
            $MU.MergeMUS = !!$TSMU."Merge 1"
            $Mu.Scope = $TSMU."Scope 1"
            $returnlist.Add($MU)
        }
        ForEach ($TSG in $TargetSite2SourcesGrouped) {
            $TSMU = $TSG.Group[0]
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TargetSite2.'Target Site 2'
            $MU.CompleteSourceURL = $TSMU.'Source 2 MUS'
            $MU.SitePermissionsSource = $SitePermissions.SitePermissionsSource
            $MU.TargetLibPrefixGiven = $TSMU.'MU Prefix 2'
            $MU.DuplicateTargetLibPrefix = $TSMU.'MU Prefix 2'
            $MU.SourceURL, $MU.ListURL, $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl $TSMU.'Source 2 MUS'
            $Mu.UniquePermissions = !!$TSMU."UP 2"
            $MU.MergeMUS = !!$TSMU."Merge 2"
            $Mu.Scope = $TSMU."Scope 2"
            $returnlist.Add($MU)
        }
        ForEach ($TSG in $TargetSite3SourcesGrouped) {
            $TSMU = $TSG.Group[0]
            $MU = New-Object MigrationUnitClass 
            $MU.SourceSC = $TSMU."Bron Site Collectie"
            $MU.DestinationURL = $TargetSite3.'Target Site 3'
            $MU.CompleteSourceURL = $TSMU.'Source 3 MUS'
            $MU.SitePermissionsSource = $SitePermissions.SitePermissionsSource
            $MU.TargetLibPrefixGiven = $TSMU.'MU Prefix 3'
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
                $TruncateLength = $DuplicatePrefix.DuplicateTargetLibPrefix.Length
                if ($TruncateLength -gt 50) {
                    $TruncateLength =49
                }      
                $DuplicatePrefix.DuplicateTargetLibPrefix = $DuplicatePrefix.DuplicateTargetLibPrefix.SubString(0, $TruncateLength) 
            }
        }

        foreach ($MU in $Returnlist) {
            $Mu.NodeID = $Settings.NodeID
            $MU.EnvironmentName = $Settings.Environment
            if ($MU.DuplicateTargetLibPrefix -eq '') {
                $DuplicateTargetLibPrefix = $MU.ListURL -replace ($MU.ListTitle, "") -Replace ("/", "") -Replace ("-", "") -Replace (" ", "")           
                $TruncateLength = $DuplicateTargetLibPrefix.Length
                if ($TruncateLength -gt 50) {
                    $TruncateLength =49
                }      
                $MU.DuplicateTargetLibPrefix = $DuplicateTargetLibPrefix.SubString(0, $TruncateLength) 
            }
        }
        return $returnlist  
    }
}