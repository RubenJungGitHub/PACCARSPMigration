using Module MigrationClasses
function Start-MtHSGMigration {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] [MigrationUnitClass[]]$MigrationItems,
        [switch]$LogPerformanceTests
    )
    $MigrationStart = Get-Date
    
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

    $SourceConnectStart= Get-Date  
    if ($MigrationItems[0].SourceURL.length -gt 5) {
        if ($settings.current.LoginType -eq 'Credentials') {
            $srcSite = Connect-Site -Url $MigrationItems[0].SourceURL -Credential $cred
        }
        else {
            $srcSite = Connect-Site -Url $MigrationItems[0].SourceURL
        }
    }
    $TSConnectSource = New-TimeSpan -Start $SourceConnectStart -End (Get-Date)
    Write-Verbose "Connected to SOURCE Site Collection $($MigrationItems[0].SourceURL) Successfully!"

    $TargetConnectStart= Get-Date  
    if ($MigrationItems[0].DestinationURL.length -gt 5) {
        if ($settings.current.LoginType -eq 'Credentials') {
            $dstSite = Connect-Site -Url $MigrationItems[0].DestinationURL -Credential $cred
        }
        else {
            $dstSite = Connect-Site -Url $MigrationItems[0].DestinationURL
        }
    }
    $TSConnectTarget = New-TimeSpan -Start $TargetConnectStart -End (Get-Date)
    Write-Verbose "Connected to TARGET Site Collection $($MigrationItems[0].DestinationUrl) Successfully!"
       
    $MigrationParameters = @{
        NormalMode          = ($settings.sharegate.migrationMode -ne 'Insane')
        Site                = $srcSite
        DestinationSite     = $dstSite
        MappingSettings     = $MappingSettings
        NoContent           = $false
        NoCustomPermissions = ($MigrationItems[0].ShareGateCopySettings -contains 'p')
        CopySettings        = $copySettings
    }

    if ($migrationItems[0].Scope -eq 'list') {
        $MigrationParameters.Remove('Site')
        $MigrationParameters.Remove('NoContent')
    }
    
    $ActualMigrationStart  = Get-Date
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
            write-Verbose "Migrating $($migrationItems.count) Lists: $($MigrationItems.ListTitle -join ', ')"
            $toCopy = Get-List -Site $srcSite | Where-Object { $_.id -in $MigrationItems.ListID } 
            $result = Copy-List -List $toCopy @MigrationParameters 
        }
    }

    $TSMigration = New-TimeSpan -Start $ActualMigrationStart -End (Get-Date)

    Write-Verbose "Completed $($MigrationItems[0].NextAction) migration of $($MigrationItems[0].SourceUrl)"
    
    $MigrationEnd = Get-Date
    if ($LogPerformanceTests.IsPresent) {
        If ($Null -eq $Result) {$Result = 'test'}
        Register-RJPerformanceTestResults -MigrationUnit $MigrationItems[0] -MigrationStart  $MigrationStart -MigrationEnd $MigrationEnd -MigrationResult $Result -TSLoadMappings $TSLoadMappings -TSConnectSource $TSConnectSource -TSConnectTarget $TSConnectTarget -TSMigration $TSMigration
    } 
    return $result
}
