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
    $items = Invoke-MtHSQLquery -QueryName 'E-ALLANDFAKE' | Where-Object { $_.NextAction -in $NextAction }
    $SiteCollectionPermissionsProcesed = [System.Collections.Generic.List[string]]::new()
    #$totalitems = $items.Count
    $i = 0
    $siteparts = $items | Group-Object -Property NextAction, SourceURL, DestinationURL, NextAction, MUStatus | Sort-Object { $_.SourceURL, $_.ListTitle }
    $siteparts = $siteparts | Sort-Object  $_.$NextAction -Descending
    $Activity = 'Processing execution cycle : '
    foreach ($part in $siteparts) {
        #start process
        $StePermissionsSource = ($Part.Group | Where-Object { $_.SitePermissionsSource -ne '' } | Select-Object -first 1).SitePermissionsSource
        if ($StePermissionsSource -ne '') {
            $MIgrateSitePermissions = ($StePermissionsSource -ne '' -and $Part.Name -Notin $SiteCollectionPermissionsProcesed)
            $SiteCollectionPermissionsProcesed.Add($Part.Name)
        }
        $StartTime = Get-Date
        $MigrunIds = [System.Collections.Generic.List[int]]::new()
        $result = Start-MtHSGMigration  -MigrationItems ($part.group | Resolve-MtHMUClass)  -LogPerformanceTests:$LogPerformanceTests  -MigrateSitePermissions:$MigrateSitePermissions

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
                $SGErrorReports = -join ($script:SGErrorReports, '\SharegateErrorReport_', $Result.SessionID, '.xlsx')
                if (!(Test-Path -path SGErrorReports)) {               
                    Export-Report -SessionId $result.SessionID -Path $SGErrorReports -overwrite
                }
                Register-MtHSQLMigRunResults -MigRunId $NewMigRunId -Result 'failed' -SGSessionId "$($env:COMPUTERNAME.Substring(7, 4))-$($result.SessionId)" -RunTimeInSec $timediff.TotalSeconds
            }
        }
    }
    Write-Progress -Activity $activity -Status 'Ready' -Completed
}