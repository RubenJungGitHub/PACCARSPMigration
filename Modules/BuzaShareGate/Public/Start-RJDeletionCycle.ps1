# Starts deletion scan for  libraryMU  Status notfound nextaction delete
# When all MU;s are deleted, all remaining MU items to be deleted will also be processed.
# this function needs to be checked ???

function Start-RJDeletionCycle {
    [CmdletBinding()]
    param( 
        
        [switch]$TestDemoList
    )

    # this is the migration script which will be run in Powershell 5.1 in a background job.   
    # get all  migration Units and/or items to be deleted 

    #Region Delete MU's
    #Double Check deletion required
    if ($settings.Current.DeleteNotFoundMUS) {
        #First get all MU's to be deleted (Double check on Status and nextaction apart from  SQL query, this also for testing/moking purposes)
        $items = Invoke-MtHSQLquery -QueryName 'R-ALL' | Where-Object { $_.MUStatus -eq 'notfound' -and $_.NextAction -eq 'delete' } | Resolve-MtHMUClass
        foreach ($item in $items) {
            if ($TestDemoList.IsPresent) {
                #Only get demolist
                $RemoveMUs = $Items | Where-Object { $_.ListTitle -eq $settings.current.MigrationURLS[0].DemoList }
            }
            else {
                $RemoveMUs = $Items
            }

            foreach ($RemoveMU in $RemoveMUs) {
                #DOUBLE CHECK REALLY NOT IN SOURCE!!!
                #Test : to be refactored 
                <#
                $URL = -Join ($RemoveMU.SourceURL, 'NONEXISTANT')
                try {
                    $Connection = Connect-MtHSharePoint -URL $URL
                    Write-Host $Connection -ForegroundColor Red
                }
                catch [System.SystemException]{
                    Write-Host $_.Exception.Message $_.Exception.ItemName  -BackgroundColor Red 
                }

                #Physical Disconnect cable
                try {
                    $Connection = Connect-MtHSharePoint -URL $RemoveMU.SourceURL
                    Write-Host $Connection -ForegroundColor Cyan
                }
                catch [System.SystemException] {
                    Write-Host $_.Exception.Message $_.Exception.ItemName  -BackgroundColor Red 
                }
#>
                #Check if list really really is non existant prior to removal  
                #To do : What if Site is deleted completely. Do we update all site lists to "Not found"?    
                $Connection = Connect-MtHSharePoint -URL $RemoveMU.SourceURL
                #Connection failed. Unable to check
                #Check if list can be found. If existant no exception  : No deletion 
                $List = Get-PnPList -Identity $item.ListTitle 
                If ($Null -ne $Connection -and $null -eq $List) {
                    #remove list 
                    $StartTime = Get-Date
                    #put started into SQL database
                    $NewMigRunId = New-MtHSQLMigRun  -MigrationType $item.NextAction -ItemNr $RemoveMU.MigUnitId
                    #run the deletion
                    $Connection = Connect-MtHSharePoint -URL $RemoveMU.DestinationUrl
                    $result = Remove-RJLibraryMU -MigrationItem $RemoveMU 

                    #put result back into SQL database
                    $timediff = New-TimeSpan -Start $startTime -End (Get-Date)
                    if ($result) {
                        # Deletion went well
                        Register-MtHSQLMigRunResults -MigRunId $NewMigRunId -Result 'Deleted' -SGSessionId 'N.A.' -RunTimeInSec $timediff.TotalSeconds
                    }
                    else {
                        # Deletion went wrong
                        Register-MtHSQLMigRunResults -MigRunId $NewMigRunId -Result 'Failed' -SGSessionId 'N.A.' -RunTimeInSec $timediff.TotalSeconds
                    }
                }
            }
        }
    }
    #endregion

    #region sync deleted  List items from target if removed from source 
    #Double Check sync required
    if ($settings.Current.MUSourceItemsDeleteSync) {
        $ItemsDeletedSuccess = 0
        $ItemsDeletedFailed = 0
        #First get all List MU's from the MU Table for item level comparison if Delta migration has occurrred
        $items = Invoke-MtHSQLquery -QueryName 'R-LISTITEMS' | Resolve-MtHMUClass
        if ($TestDemoList.IsPresent) {
            #Only get demolist
            $SyncMUs = $Items | Where-Object { $_.ListTitle -eq $settings.current.MigrationURLS[0].DemoList }
        }
        else {
            $SyncMUs = $Items
        }
        $StartTime = Get-Date
        foreach ($SyncMU in $SyncMUs) {
            #Connect to item source List 
            Connect-MtHSharePoint -URL $SyncMU.SourceUrl  | Out-Null
            #Collect source items 
            $SourceFiles = (Get-PnPListItem -List $SyncMU.ListTitle -Fields FileLeafRef, FileRef, File_x0020_Size  -PageSize 1000 | Where-Object { $_['FileLeafRef'] -like '*.*' }) | ForEach-Object { New-Object PSObject -Property @{FileLeafRef = $_['FileLeafRef']; FileRef = $_['FileRef']; Length = $_['File_x0020_Size'] } } | Select-Object FileLeafRef, FileRef, Length
            $SourceFiles | ForEach-Object { $SourceMUSize += [int64] $_.Length; $SourceMUCount++ }
            #Connect to item destination List 
            Connect-MtHSharePoint -URL $SyncMU.DestinationUrl | Out-Null
            #Collect target items 
            $TargetFiles = (Get-PnPListItem -List $SyncMU.ListTitle -Fields FileLeafRef, FileRef, File_x0020_Size  -PageSize 1000 | Where-Object { $_['FileLeafRef'] -like '*.*' }) | ForEach-Object { New-Object PSObject -Property @{FileLeafRef = $_['FileLeafRef']; FileRef = $_['FileRef']; Length = $_['File_x0020_Size'] } } | Select-Object FileLeafRef, FileRef, Length
            $TargetFiles | ForEach-Object { $TargetMUSize += [int64] $_.Length; $TargetMUCount++ }
            #Check if differences in MU in target and Source. If not: neglect
            If ($TargetMUSize -ne $SourceMUSize -or $TargetMUCount -ne $SourceMUCount) {
                $NewMigRunId = New-MtHSQLMigRun  -MigrationType $SyncMU.NextAction -ItemNr $SyncMU.MigUnitId
                $Differences = Compare-Object -ReferenceObject $SourceFiles -DifferenceObject $TargetFiles -Property FileLeafRef
                $DeleteTargetFiles = $TargetFiles | Where-Object { $_.FileLeafRef -in $Differences.FileLeafRef }
                foreach ($DeleteFile in $DeleteTargetFiles) {
                    try {
                        Remove-PnPFile -ServerRelativeUrl $DeleteFile.FileRef  -Force 
                        $ItemsDeletedSuccess++ 
                    }
                    catch {
                        $ItemsDeletedFailed++ 
                    }
                    Remove-PnPFile -ServerRelativeUrl $DeleteFile.FileRef  -Force 
                }
                $timediff = New-TimeSpan -Start $startTime -End (Get-Date)
                Register-MtHSQLMigRunResults -MigRunId $NewMigRunId -Result 'success' -SGSessionId 'N.A.' -RunTimeInSec $timediff.TotalSeconds -Details ($ItemsDeletedSuccess.ToString() + ' items deleted succesfully. ' + $ItemsDeletedFailed.ToString() + ' deletion(s) failed')
            }
        }
    }
    #endregion
}
