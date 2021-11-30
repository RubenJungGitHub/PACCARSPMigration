using module MigrationClasses
function Register-RJPerformanceTestResults {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)][MigrationUnitClass]$MigrationUnit,
        [parameter(Mandatory = $true)][PSCustomObject]$MigrationStart,
        [parameter(Mandatory = $true)][PSCustomObject]$MigrationEnd,
        [parameter(Mandatory = $true)][PSCustomObject]$MigrationResult,
        [parameter(Mandatory = $true)][PSCustomObject]$TSLoadMappings,
        [parameter(Mandatory = $true)][PSCustomObject]$TSConnectSource,
        [parameter(Mandatory = $true)][PSCustomObject]$TSConnectTarget,
        [parameter(Mandatory = $true)][PSCustomObject]$TSMigration
    )
    $script:MigrationPerformanceResultsLogFile = $settings.PerformanceCsv
    Connect-MtHSharePoint -URL $MigrationUnit.SourceURL | Out-Null 
    $List = Get-PnPList -Identity $MigrationUnit.ListTitle
    $MuSize = 0
    Get-PnPListItem -List $List.Title -PageSize 1000 | ForEach-Object { $MUSize += ($_.FieldValues.File_x0020_Size) }
    $Script:SourceMetadata =
    [PSCustomObject]@{
        MuItemCount = $List.ItemCount
        MUSizeB     = $MUSize
        MUSizeKB    = [math]::Round($MuSize / 1KB, 0)
        MUSizeMB    = [math]::Round($MUSize / 1MB, 2)
        MUSizeAVGKB = [math]::Round(($MUSize / 1KB) / $List.ItemCount)
    }
    $TimeSpan = New-TimeSpan -Start $MigrationStart -End $MigrationEnd
    $MigrationresultItem = [PSCustomObject]@{
        MigrationUNitID                     = $MigrationUnit.MigUnitId
        SourceSite                          = $MigrationUnit.SourceURL
        SourceMU                            = $MigrationUnit.ListURL
        MUTitle                             = $MigrationUnit.ListTitle
        SGSessionID                         = "$($env:COMPUTERNAME.Substring(7, 4))-$($result.SessionId)"
        # SGItemsCopied                       = $MigrationResult.ItemsCopied
        # SGISiteObjectsCopied                = $MigrationResult.SiteObjectsCopied
        SGOutcome                           = $MigrationResult.Result
        SGSuccess                           = $MigrationResult.Successes
        SGErrors                            = $MigrationResult.Errors
        SGWarnings                          = $MigrationResult.Warnings
        Action                              = $MigrationUnit.NextAction
        Machine                             = $env:COMPUTERNAME
        NodeID                              = $MigrationUnit.NodeId
        Start                               = $MigrationStart
        End                                 = $MigrationEnd
        MuItemCount                         = $Script:SourceMetaData.MuItemCount
        MUSize_KB                           = $Script:SourceMetaData.MUSizeKB
        AverageFileSizeThisRun_KB           = $Script:SourceMetaData.MUSizeAVGKB
        TSLoadMapping                       = [math]::Round($TSLoadMappings.TotalSeconds, 0)
        TSConnectSource                     = [math]::Round($TSConnectSource.TotalSeconds, 0)
        TSConnectTarget                     = [math]::Round($TSConnectTarget.TotalSeconds, 0)
        TSActualMigration                   = [math]::Round($TSMigration.TotalSeconds, 0)
        MUProcessingSeconds                 = [math]::Round($TimeSpan.TotalSeconds, 0)
       <# AverageProcsesingSecsPerItem_ThisMU = if ($Script:SourceMetaData.MuItemCount -ne 0) {
            [math]::Round(($TimeSpan.TotalSeconds / $Script:SourceMetaData.MuItemCount), 2).ToString()
        }
        else {
            'Unknown :  devision by 0. Issues determining results in target'
        }
        AverageProcessingSecsPerMB_ThisMU   = if ($Script:SourceMetaData.MUSIzeMB -ne 0) {
            [math]::Round(($TimeSpan.TotalSeconds / $Script:SourceMetaData.MUSIzeMB), 2).ToString()
        }
        else {
            'Unknown :  devision by 0. Issues determining results in target'
        }
        #>
    }
    $MigrationresultItem | Export-Csv -Path $MigrationPerformanceResultsLogFile -Append -Delimiter ';' -Encoding UTF8   -NoTypeInformation
}