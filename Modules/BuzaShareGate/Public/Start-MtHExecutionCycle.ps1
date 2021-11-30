using module MigrationClasses 
# function to execute all "to do" migrations (real or fake)
function Start-MtHExecutionCycle {
    [CmdletBinding()]
    param( 
        [switch] $LogPerformanceTests, 
        [Parameter(Mandatory = $false)][String[]][ValidateSet('first', 'delta')]$NextAction)


    #If nextaction missing process all
    if ($Null -eq $NextAction -or '' -eq $NextAction) {
        $Nextaction = @('first', 'delta')
    }

    # get all active migration Units
    #NOT WORKING. Sometimes you can add items, sometimes not
    #$items = Invoke-MtHSQLquery -QueryName 'E-ALL' | Where-Object { $_.NextAction -in $NextAction }
    #$items += Invoke-MtHSQLquery -QueryName 'E-Fake' | Where-Object { $_.NextAction -in $NextAction }
    $items += Invoke-MtHSQLquery -QueryName 'E-ALLANDFAKE' | Where-Object { $_.NextAction -in $NextAction }

    $totalitems = $items.Count
    $i = 0
    $siteparts = $items | Group-Object -Property SourceUrl, NextAction, ShareGateCopySettings, MUStatus
    $Activity = 'Processing execution cycle : '
    foreach ($part in $siteparts) {
        #start process
        $StartTime = Get-Date
        $MigrunIds = [System.Collections.Generic.List[int]]::new()
        foreach ($item in $part.group) {
            $Fake = ($Item.MUStatus -eq 'fake')
            $Activity += If($Fake){'Execute fake Migration'}else{'Execute real Migration'}
            Write-Progress -Activity $activity -Status "$i of $totalitems Complete" -PercentComplete $($i++ * 100 / $totalitems)
            #put started into SQL database
            $NewMigRunId = New-MtHSQLMigRun -MigrationType $item.NextAction -ItemNr $item.MigUnitId -Fake:$fake
            $MigrunIds.Add($NewMigRunId)
            #run the migration itself
            if ($Fake) {
                # fake the run, to fill the run database
                $Script:result = Start-MtHFakeMigration -MigrationItem $item
            }   
        }
        # real process
        if (!$Fake) {
            $result = Start-MtHSGMigration  -MigrationItems ($part.group | Resolve-MtHMUClass)  -LogPerformanceTests:$LogPerformanceTests
        }
        $EndTime = Get-Date
        $timediff = New-TimeSpan -Start $startTime -End $EndTime
        foreach ($NewMigRunId in $MigrunIds) {
            #put result back into SQL database
            if ($result.Errors -eq 0) {
                # Migration went well
                Register-MtHSQLMigRunResults -MigRunId $NewMigRunId -Result 'success' -SGSessionId "$($env:COMPUTERNAME.Substring(7, 4))-$($result.SessionId)" -RunTimeInSec $timediff.TotalSeconds
            }
            else {
                # Migration went wrong
                #Export Error Report
                $SGErrorReports = -join ($script:SGErrorReports, $Result.SessionID, '_Node_', $Settings.NodeId, '.xlsx')
                Export-Report $result -Path $SGErrorReports 
                Register-MtHSQLMigRunResults -MigRunId $NewMigRunId -Result 'failed' -SGSessionId "$($env:COMPUTERNAME.Substring(7, 4))-$($result.SessionId)" -RunTimeInSec $timediff.TotalSeconds
            }
        }
    }
    Write-Progress -Activity $activity -Status 'Ready' -Completed
}