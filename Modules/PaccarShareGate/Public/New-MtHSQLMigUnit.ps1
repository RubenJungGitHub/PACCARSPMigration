Using Module MigrationClasses
function New-MtHSQLMigUnit {
    [CmdletBinding()]
    Param(
        [parameter(mandatory = $true)] [PSCustomObject] $Item,
        [Parameter(Mandatory = $false)][String][ValidateSet(“first”,”delta”)]$NextAction,
        [switch]$Activate
    )
    if($Activate)
    {
        $Item.MUStatus = 'Active'
        If ($NextAction)
        {$Item.NextAction = $NextAction}
    }

    #query to create a new entry in the MigrationUnits Table
    $sql = @"
        INSERT INTO MigrationUnits
        (EnvironmentName, SourceSC, CompleteSourceURL ,SourceUrl, DestinationUrl, DuplicateTargetLibPrefix, ListUrl, ListTitle, ShareGateCopySettings, UniquePermissions, Scope, MUStatus, NextAction, NodeId, CreationTime)
        VALUES
        ('$($Item.EnvironmentName)','$($Item.SourceSC)','$($Item.CompleteSourceURL)', '$($Item.SourceUrl.replace("`'","`'`'"))','$($Item.DestinationUrl.replace("`'","`'`'"))','$($Item.DuplicateTargetLibPrefix)','$($Item.ListUrl.replace("`'","`'`'"))', N'$($Item.ListTitle.replace("`'","`'`'"))', '$($Item.ShareGateCopySettings)','$($Item.UniquePermissions)','$($Item.Scope)','$($Item.MUStatus)','$($Item.NextAction)', 1,  SYSDATETIME());        
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