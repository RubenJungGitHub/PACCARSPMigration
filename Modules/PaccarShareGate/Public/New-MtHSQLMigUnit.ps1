Using Module MigrationClasses
function New-MtHSQLMigUnit {
    [CmdletBinding()]
    Param(
        
        [parameter(mandatory = $true)] [PSCustomObject] $Item
    )
    #query to create a new entry in the MigrationUnits Table
    $sql = @"
        INSERT INTO MigrationUnits
        (EnvironmentName, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId, ListTemplate, ShareGateCopySettings, Scope, MUStatus, NextAction, NodeId, ItemCount, CreationTime)
        VALUES
        ('$($Item.EnvironmentName)','$($Item.SourceUrl.replace("`'","`'`'"))','$($Item.DestinationUrl.replace("`'","`'`'"))','$($Item.ListUrl.replace("`'","`'`'"))', N'$($Item.ListTitle.replace("`'","`'`'"))','$($Item.ListId)',
        '$($Item.ListTemplate)', '$($Item.ShareGateCopySettings)','$($Item.Scope)','$($Item.MUStatus)','$($Item.NextAction)', 1, $($Item.ItemCount), SYSDATETIME());        
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