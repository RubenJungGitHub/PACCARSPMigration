using module MigrationClasses 
# function to execute all "to do" migrations (real or fake)
function Start-MtHExecutionCycle {
    [CmdletBinding()]
    param( 
        [switch] $LogPerformanceTests, 
        [Parameter(Mandatory = $false)][String[]][ValidateSet('first', 'delta')]$NextAction,
         [switch]$TestSPConnections)


    #If nextaction missing process all
    if ($Null -eq $NextAction -or '' -eq $NextAction) {
        $Nextaction = @('first', 'delta')
    }

    # get all active migration Units
    #NOT WORKING. Sometimes you can add items, sometimes not
    #$items = Invoke-MtHSQLquery -QueryName 'E-ALL' | Where-Object { $_.NextAction -in $NextAction }
    #$items += Invoke-MtHSQLquery -QueryName 'E-Fake' | Where-Object { $_.NextAction -in $NextAction }
    $items = Invoke-MtHSQLquery -QueryName 'E-ALLANDFAKE' | Where-Object { $_.NextAction -in $NextAction }
    $totalitems = $items.Count
    $SiteCollectionPermissionsProcesed = [System.Collections.Generic.List[string]]::new()
    #$totalitems = $items.Count
    if (-Not $TestSPConnections) {
        $i = 0
        $siteparts = $items | Group-Object -Property NextAction, SourceURL, DestinationURL, MUStatus | Sort-Object { $_.SourceURL, $_.ListTitle }
        $siteparts = $siteparts | Sort-Object  $_.$NextAction -Descending
        $Activity = 'Processing execution cycle : '
        foreach ($part in $siteparts) {
            $StartTime = Get-Date
            $MigrunIDS = [System.Collections.Generic.List[PSCustomObject]]::new()
            $StePermissionsSource = ($Part.Group | Where-Object { $null -ne $_.SitePermissionsSource } | Select-Object -first 1).SitePermissionsSource
            $MIgrateSitePermissions = ($null -ne $StePermissionsSource -and $Part.Group[0].DestinationUrl -Notin $SiteCollectionPermissionsProcesed)
            $SiteCollectionPermissionsProcesed.Add($Part.Group[0].DestinationUrl)
            foreach ($item in $part.group) {
                $fake = ($Item.MuStatus -eq 'fake')
                Write-Progress -Activity $activity -Status "$i of $totalitems Complete" -PercentComplete $($i++ * 100 / $totalitems)
                #put started into SQL database
                $NewMigRunId = New-MtHSQLMigRun -MigrationType $item.NextAction -ItemNr $item.MigUnitId -Fake:$fake
                $MigRunID = [PSCustomObject]@{
                    MigRunID  = $NewMigRunId
                    MigUnitID = $Item.MigUnitID            
                }
                $MigrunIds.Add($MigRunID)
 
                #Run the Fake migration if appropriate
            }
            $migresults = Start-MtHSGMigration  -MigrationItems ($part.group | Resolve-MtHMUClass)  -LogPerformanceTests:$LogPerformanceTests  -MigrateSitePermissions:$MigrateSitePermissions -DisableSSO:$Settings.Current.DisableSSO
            $results = $migresults | Where-object { $null -ne $_.Result }
            $EndTime = Get-Date
            $timediff = New-TimeSpan -Start $startTime -End $EndTime
            foreach ($result in $results) {
                $MigRunResults = $MigRunIDS | Where-object { $_.MigUnitID -in $Result.MigUNitIDs }
                #put result back into SQL database
                if ($result.Errors -eq 0) {
                    # Migration went well
                    $MigRunResults | ForEach-Object { Register-MtHSQLMigRunResults -MigRunId $_.MigRunID -Result 'success' -SGSessionId "$($env:COMPUTERNAME.Substring(7, 4))-$($result.Result.SessionId)" -RunTimeInSec $timediff.TotalSeconds }
                }
                else {
                    # Migration went wrong
                    #Export Error Report
                    $SGErrorReports = -join ($Settings.Filepath.SGErrorReports, '\SharegateErrorReport_', $result.SessionID, '.xlsx')
                    if (!(Test-Path -path SGErrorReports)) {               
                        Export-Report -SessionId $result.Result.SessionID -Path $SGErrorReports -overwrite
                    }
                    $MigRunResults | ForEach-Object { Register-MtHSQLMigRunResults -MigRunId $_.MigRunID -Result 'failed' -SGSessionId "$($env:COMPUTERNAME.Substring(7, 4))-$($result.Result.SessionId)" -RunTimeInSec $timediff.TotalSeconds }
                }
            }
            #Update SQL DB with MU;s not in SOurce
            $sql = @"
    UPDATE MigrationUnits
    SET ListID = 'NOT DETECTED IN SOURCE' 
    WHERE  LISTID IS NULL OR LISTID = ''
"@
            Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
            Write-Progress -Activity $activity -Status 'Ready' -Completed
        }
    }
    else {
        $siteparts = $items | Group-Object -Property SourceURL, DestinationURL | Sort-Object { $_.SourceURL, $_.ListTitle }
        $siteparts = $siteparts | Sort-Object  $_.SourceURL -Descending
        $Activity = 'Processing execution cycle : '
        foreach ($part in $siteparts) {
            $migresults = Start-MtHSGMigration  -MigrationItems ($part.group | Resolve-MtHMUClass)  -LogPerformanceTests:$LogPerformanceTests  -MigrateSitePermissions:$MigrateSitePermissions -DisableSSO:$Settings.Current.DisableSSO -TestSPConnections:$TestSPConnections
        }
    }
}