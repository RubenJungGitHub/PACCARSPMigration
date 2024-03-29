﻿Using Module MigrationClasses
function New-MtHSQLMigUnit {
    [CmdletBinding()]
    Param(
        [parameter(mandatory = $true)] [PSCustomObject] $Item,
        [Parameter(Mandatory = $false)][String][ValidateSet(“first”, ”delta”)]$NextAction,
        [switch]$Activate
    )
    if ($Activate) {
        $Item.MUStatus = 'Active'
        If ($NextAction)
        { $Item.NextAction = $NextAction }
    }

    #Single step SubString NOT working
    $ListTitleWithPrefix = -Join ($Item.ListTitle.replace("`'", "`'`'"), $Item.DuplicateTargetLibPrefix)
    If ($ListTitleWithPrefix.Length -gt 50) {
        $ListTitleWithPrefix = $ListTitleWithPrefix.SubString(0, 50)
    }
    #query to create a new entry in the MigrationUnits Table
    #$sql = @"
    #    INSERT INTO MigrationUnits
    #    (EnvironmentName, SourceSC, CompleteSourceURL ,SitePermissionsSource, SourceUrl, DestinationUrl, DuplicateTargetLibPrefix, TargetLibPrefixGiven, ListUrl, ListTitle, ListTitleWithPrefix,  ShareGateCopySettings, UniquePermissions, MergeMUS, Scope, MUStatus, NextAction, NodeId, CreationTime)
    #    VALUES
    #    ('$($Item.EnvironmentName)','$($Item.SourceSC)','$($Item.CompleteSourceURL)', '$($Item.SitePermissionsSource)','$($Item.SourceUrl.replace("`'","`'`'"))','$($Item.DestinationUrl.replace("`'","`'`'"))','$($Item.DuplicateTargetLibPrefix)','$($Item.TargetLibPrefixGiven)','$($Item.ListUrl.replace("`'","`'`'"))', '$($Item.ListTitle.replace("`'","`'`'"))', CONCAT('$($Item.ListTitle.replace("`'","`'`'"))','$($Item.DuplicateTargetLibPrefix)'), '$($Item.ShareGateCopySettings)','$($Item.UniquePermissions)','$($Item.MergeMUS)','$($Item.Scope)','$($Item.MUStatus)','$($Item.NextAction)', 1,  SYSDATETIME());        
    #"@
    $sql = @"
        INSERT INTO MigrationUnits
        (EnvironmentName, SourceSC, CompleteSourceURL ,SitePermissionsSource, SourceRoot, SourceUrl, DestinationUrl, DuplicateTargetLibPrefix, TargetLibPrefixGiven, ListUrl, ListTitle, ListTitleWithPrefix,  ShareGateCopySettings,InheritFromSource, UniquePermissions, MergeMUS, Scope, MUStatus, NextAction, NodeId, CreationTime)
        VALUES
        ('$($Item.EnvironmentName)','$($Item.SourceSC)','$($Item.CompleteSourceURL)', '$($Item.SitePermissionsSource)','$($Item.SourceRoot)','$($Item.SourceUrl.replace("`'","`'`'"))','$($Item.DestinationUrl.replace("`'","`'`'"))','$($Item.DuplicateTargetLibPrefix)','$($Item.TargetLibPrefixGiven)','$($Item.ListUrl.replace("`'","`'`'"))', '$($Item.ListTitle.replace("`'","`'`'"))', '$($ListTitleWithPrefix)', '$($Item.ShareGateCopySettings)','$($Item.InheritFromSource)','$($Item.UniquePermissions)','$($Item.MergeMUS)','$($Item.Scope)','$($Item.MUStatus)','$($Item.NextAction)', 1,  SYSDATETIME());        
"@

    # $item | Write-SqlTableData -ServerInstance $Settings.SQLDetails.Instance -DatabaseName $Settings.SQLDetails.Database -SchemaName "dbo" -TableName MigrationUnits
    # and return the Migration Units
    try {
        return Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql -ErrorAction Stop | Resolve-MtHMUClass
    } 
    catch {
        $ErrorMessage = $_ | Out-String
        $ErrorMessage += 'Error occured on following object:'
        $ErrorMessage += $Item | Format-List | Out-String
        $ErrorMessage += 'Error occured on following SQL here-string:'
        $ErrorMessage += $sql
        Write-Error $ErrorMessage
        return $null
    }
}