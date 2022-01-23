using Module MigrationClasses
function Start-MtHSGMigration {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] [MigrationUnitClass[]]$MigrationItems,
        [switch]$LogPerformanceTests,
        [switch]$MigrateSitePermissions,
        [switch]$DisableSSO,
        [switch]$TestSPConnections
    )
    $BatchSTart = 0
    $MigrationStart = Get-Date
    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
    # $MigrationItems = @($MigrationItem)
    Write-Verbose "Initiate Load mappings and copy settings"
    $MappingSettings = New-MappingSettings
    if ( $Settings.sharegate.userMap ) {
        $UserMappingsPath = $settings.FilePath.Mappings + '\UserAndGroupMappings.sgum'
        Import-UserAndGroupMapping -Path $UserMappingsPath -MappingSettings $MappingSettings | Out-Null
    }
    if ( $Settings.sharegate.ContentTypeMap ) {
        $UserMappingsPath = $settings.FilePath.Mappings + '\ContentTypeMappings.sgctm'
        Import-ContentTypeMapping -Path $UserMappingsPath -MappingSettings $MappingSettings | Out-Null
    }
    if ( $settings.sharegate.templateMap ) {
        $SiteTemplateMappingsPath = $settings.FilePath.Mappings + '\SiteTemplateMappings.sgwtm'
        Import-SiteTemplateMapping -Path $SiteTemplateMappingsPath -MappingSettings $MappingSettings | Out-Null
    }
    if ( $settings.sharegate.PermissionsMap ) {
        $SitePermissionsMappingsPath = $settings.FilePath.Mappings + '\PermissionLevelMappings.sgrm'
        Import-PermissionLevelMapping -Path $SitePermissionsMappingsPath -MappingSettings $MappingSettings | Out-Null
    }
    if ( $settings.sharegate.PropertyMap ) {
        $SitePropertyMappingsPath = $settings.FilePath.Mappings + '\PropertyMappings.sgpm'
        Import-PropertyMapping -Path $SitePropertyMappingsPath -MappingSettings $MappingSettings | Out-Null
    }
    
    #load specific settings, for example incremental update of a site
    if ($MigrationItems[0].NextAction -eq 'Delta') {
        $CopySettings = New-CopySettings -OnContentItemExists IncrementalUpdate
    }
    else {
        $CopySettings = New-CopySettings -OnContentItemExists Overwrite
    }

    $TSLoadMappings = New-TimeSpan -Start $MigrationStart -End (Get-Date)
    Write-Verbose 'Completed mappings and copy settings load' 

    #different Site, List and Library options executed
    #reporting to adapt ....???
    $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserName, $securePwd
    $SourceConnectStart = Get-Date  
    if ($MigrationItems[0].SourceURL.length -gt 5) {
        if ($settings.current.LoginType -eq 'Credentials') {
            $srcSite = Connect-Site -Url $MigrationItems[0].SourceURL -Credential $cred 
        }
        else {
            #For Paccar SP2010 
            $srcSite = Connect-Site -Url $MigrationItems[0].SourceURL

            #For Demo (Office365 Source)
            #$srcSite = Connect-Site -Url $MigrationItems[0].SourceURL -Browser -DisableSSO:$DisableSSO
        }
    }
    $TSConnectSource = New-TimeSpan -Start $SourceConnectStart -End (Get-Date)
    Write-Verbose "Connected to SOURCE Site Collection $($MigrationItems[0].SourceURL) Successfully!"

    $TargetConnectStart = Get-Date  
    if ($MigrationItems[0].DestinationURL.length -gt 5) {
        if ($settings.current.LoginType -eq 'Credentials') {
            $dstSite = Connect-Site -Url $MigrationItems[0].DestinationURL -Credential $cred 
        }
        else {
            $dstSite = Connect-Site -Url $MigrationItems[0].DestinationURL -Browser -DisableSSO:$DisableSSO
        }
    }
    $TSConnectTarget = New-TimeSpan -Start $TargetConnectStart -End (Get-Date)
    Write-Verbose "Connected to TARGET Site Collection $($MigrationItems[0].DestinationUrl) Successfully!"
       
    $MigrationParameters = @{
        NormalMode      = ($settings.sharegate.migrationMode -ne 'Insane')
        Site            = $srcSite
        DestinationSite = $dstSite
        MappingSettings = $MappingSettings
        NoContent       = $false
        #NoCustomPermissions = ($MigrationItems[0].ShareGateCopySettings -contains 'p')
        CopySettings    = $copySettings
    }

    if ($migrationItems[0].Scope -eq 'list') {
        $MigrationParameters.Remove('Site')
        $MigrationParameters.Remove('NoContent')
    }
    
    if ($TestSPConnections) {
        If ($srcSite -AND $dstSite) {
            Write-Host "Test SP connection only, no actual migration.   Destination $($dstSite) and source $($srcSite)  accessible" -ForegroundColor Black -BackgroundColor Green
        }
        Else {
            Write-Host "Test SP connection only, no actual migration.   Destination $($dstSite) or  source $($srcSite) NOT accessible" -ForegroundColor Black -BackgroundColor red
        }
        Return $Null
    }
    else {
        Write-Host "MIGRATE  source $($srcSite) to Destination $($dstSite)"  -ForegroundColor Cyan
        $ActualMigrationStart = Get-Date
        if ($MigrateSitePermissions) {
            Copy-ObjectPermissions -Source $srcSite -Destination $dstSite | out-null 
        }

        switch ($MigrationItems[0].Scope) {
            'site' { 
                Write-Verbose 'Initiate site copy......' 
                $ParamInfo = ($MigrationParameters | convertTo-Json -Depth 5) -replace '\s' -replace '"'
                Write-Verbose "Paramaters:  $ParamInfo"
                $result = Copy-Site @MigrationParameters 
            }
            'list' {
                Write-Verbose 'Initiate list copy.......' 
                $ParamInfo = ($MigrationParameters | convertTo-Json -Depth 5) -replace '\s' -replace '"'
                Write-Verbose "Paramaters:  $ParamInfo"
                write-Host "Migrating $($migrationItems.count) Lists: $($MigrationItems.ListTitle -join ', ')" -f green
                $ToCopy = Get-List -Site $srcSite | Where-Object { $_.Title -in $MigrationItems.ListTitle -or $_.Title.replace(' ', '' ) -in $MigrationItems.ListTitle } 
                #To do check Empty ToCopy
                if ($Null -eq $ToCopy) {
                    Write-Host  "Eror detecting renamed MU-s to copy not detected  : MUs passed : $($MigrationItems.CompleteSourceUrl)" -BackgroundColor red
                }
                $renamedLists = Rename-RJListsTitlePrefix -Lists $ToCopy -MUS $MigrationItems -dstSite $dstSite.Address
                $ListTitleWithPrefix
                foreach ($List in $RenamedLists) {
                    write-Host "Migrating Renamedlist $($List.ListTitleWithPrefix)"  -f Magenta
                    if ($List.MergeMUS) { $ListTitleWithPrefix = -Join ($List.ListTitle, $List.TargetLibPrefixGiven) }
                    else {
                        $ListTitleWithPrefix = ( -Join ($List.ListTitle, $List.DuplicateTargetLibPrefix))
                        #Max listname length truncation
                        If ($ListTitleWithPrefix.Length -gt 50) {
                            $ListTitleWithPrefix = $ListTitleWithPrefix.SubString(0, 50)
                        }
                    }
                    #Find original source list Title and copy MU
                    $SourceSiteList = $ToCopy | where-Object { $_.RootFolder.SubString(0, $_.RootFolder.Length - 1) -eq $List.ListURL }
                    $result = Copy-List  -SourceSite $srcSite  -Name $SourceSiteList.Title  -ListTitleUrlSegment $ListTitleWithPrefix -ListTitle $ListTitleWithPrefix -NoWorkflows -NoWebParts -NoNintexWorkflowHistory -ForceNewListExperience -NoCustomizedListForms -WaitForImportCompletion:$Settings.WaitForImportCompletion  @MigrationParameters
                    $MigrationresultItem = [PSCustomObject]@{
                        Result     = $result
                        MigUnitIDs = $List.MigUNitID 
                    }
                    $Results.Add($MigrationresultItem)
                    #Register related MU Id's
                    if ($Null -ne $ListTitleWithPrefix) {
                        Register-RJListID -scrSite $srcSite -dstSite  $dstSite -List $List -RenamedList $ListTitleWithPrefix
                    }
                    Write-Progress "Check custom permissions required for renamed item "
                    if ($List.UniquePermissions) {
                        $DestinationList = Get-List -Site $dstSite -Name $ListTitleWithPrefix
                        $result = Copy-ObjecPermissions -Source $SourceSiteList -Destination $DestinationList
                        $MigrationresultItem = [PSCustomObject]@{
                            Result     = $result
                            MigUnitIDs = $List.MigUNitID
                        }
                        $Results.Add($MigrationresultItem)
                    }
                }
                $BatchWiseLists = $MigrationItems | Where-Object { $_.ListTitle -NotIn $renamedLists.ListTitle }
                if ($BatchWiseLists ) {
                    #Drop renamed lists
                    $toCopyBatchAll = Get-List -Site $srcSite | Where-Object { ($_.Title -in $BatchWiseLists.ListTitle -or $_.Title -in $MigrationItems.ListTitle.replace(' ', '' )) -and $_. Title -NotIn $renamedLists.ListTitle } 
                    if ($NUll -eq $toCopyBatchAll) {
                        Write-Host  "Eror detecting MU-s batch  to copy not detected:  MUs passed :  $($BatchWiseLists.CompleteSourceUrl)   "-BackgroundColor red
                    }
                    #For Throttling reasons limit number of lists to 5 and split 
                    $BatchCycleCounter = [math]::Ceiling($toCopyBatchAll.Length / $Settings.MigrationBatchSplitSize)
                    write-Host "Complete batch split into $($BatchCycleCounter) runs of $($Settings.MigrationBatchSplitSize) migrationunits"  -f DarkYellow
                    For ($b = 0; $b -lt $BatchCycleCounter; $b++) {
                        $BatchEnd = $BatchStart + $Settings.MigrationBatchSplitSize-1
                        $ToCopyBatch = $toCopyBatchAll[$BatchSTart..$BatchEnd]
                        $BatchStart = $BatchEnd +1 
                        write-Host "Migrating batch $($ToCopyBatch.Title)"  -f CYAN
                        $result = Copy-List -List $toCopyBatch  -NoWorkflows -NoWebParts -NoNintexWorkflowHistory -ForceNewListExperience -NoCustomizedListForms  -WaitForImportCompletion:$Settings.WaitForImportCompletion @MigrationParameters
                        $MigrationresultItem = [PSCustomObject]@{
                            Result     = $result
                            MigUnitIDs = $MigrationItems.MigUNitID
                        }
                        $Results.Add($MigrationresultItem)
                        if ($Null -ne $ToCopyBatch) { Register-RJListID -scrSite $srcSite -dstSite  $dstSite  -Lists $ToCopyBatch }
                        Write-Progress "Check custom permissions required for batch item "
                        ForEach ($MigrationItem in $BatchWiseLists) {
                            if ($MigrationItem.UniquePermissions) {
                                $SourceList = Get-List -Site $SrcSite -Name $MigrationItem.ListTitle
                                $DestinationList = Get-List -Site $dstSite -Name $MigrationItem.ListTitle
                                $result = Copy-ObjectPermissions -Source $SourceList -Destination $DestinationList 
                                $MigrationresultItem = [PSCustomObject]@{
                                    Result     = $result
                                    MigUnitIDs = $MigrationItems.MigUNitID
                                }
                                $Results.Add($ReMigrationresultItemsult)
                            }
                        }
                    }
                }
            }
        }

        $TSMigration = New-TimeSpan -Start $ActualMigrationStart -End (Get-Date)

        Write-Verbose "Completed $($MigrationItems[0].NextAction) migration of $($MigrationItems[0].SourceUrl)"
    
        $MigrationEnd = Get-Date
        if ($LogPerformanceTests.IsPresent) {
            If ($Null -eq $Result) { $Result = 'test' }
            Register-RJPerformanceTestResults -MigrationUnit $MigrationItems[0] -MigrationStart  $MigrationStart -MigrationEnd $MigrationEnd -MigrationResult $Result -TSLoadMappings $TSLoadMappings -TSConnectSource $TSConnectSource -TSConnectTarget $TSConnectTarget -TSMigration $TSMigration
        } 
        return $results
    }
}
